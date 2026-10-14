import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select
from sqlalchemy import func, text
from models import Post, User, PostCreate, PostUpdate, PostResponse, PostListResponse, CommentCreate
from auth import get_current_user
from database import get_session

router = APIRouter(prefix="/posts", tags=["posts"])
logger = logging.getLogger(__name__)


@router.get("", response_model=PostListResponse)
async def get_posts(
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(10, ge=1, le=10, description="Items per page (max 10)"),
    user_id: Optional[int] = Query(None, description="Filter by user ID"),
    session: Session = Depends(get_session)
):
    """
    Get paginated list of posts.
    
    This endpoint is public and does not require authentication.
    """
    logger.info(
        "Fetching posts (page=%s, limit=%s, filtered_by_user=%s)",
        page,
        limit,
        user_id is not None,
    )
    # Calculate offset
    offset = (page - 1) * limit
    
    # Build query
    statement = select(Post)
    
    # Filter by user_id if provided
    if user_id:
        statement = statement.where(Post.user_id == user_id)
    
    # Get total count
    count_statement = select(func.count()).select_from(statement.subquery())
    total_result = await session.execute(count_statement)
    total = total_result.scalar()
    
    # Get posts with pagination
    statement = statement.order_by(Post.created_at.desc()).offset(offset).limit(limit)
    result = await session.execute(statement)
    posts = result.scalars().all()
    logger.info("Retrieved %s posts (total=%s, page=%s)", len(posts), total, page)
    
    # Calculate total pages
    pages = (total + limit - 1) // limit if total > 0 else 0
    
    return PostListResponse(
        posts=posts,
        total=total,
        page=page,
        limit=limit,
        pages=pages
    )


@router.post("", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_post(
    post_data: PostCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """
    Create a new post.
    
    Requires authentication via JWT token.
    """
    logger.info("Creating post for user_id=%s", post_data.user_id)
    # Verify user exists
    user = await session.get(User, post_data.user_id)
    if not user:
        logger.warning("Post creation failed: user_id=%s was not found", post_data.user_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Create post
    post = Post(
        user_id=post_data.user_id,
        content=post_data.content,
        likes_count=0,
        comments=[]
    )
    
    session.add(post)
    await session.commit()
    await session.refresh(post)
    
    logger.info("Created post_id=%s for user_id=%s", post.id, post.user_id)
    return post


@router.put("/{post_id}", response_model=PostResponse)
async def update_post(
    post_id: int,
    post_data: PostUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """
    Update a post.
    
    Requires authentication via JWT token.
    Only the post owner can update their own posts.
    """
    logger.info("Updating post_id=%s for user_id=%s", post_id, current_user.id)
    # Get post
    post = await session.get(Post, post_id)
    if not post:
        logger.warning("Post update failed: post_id=%s was not found", post_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found"
        )
    
    # Check if user is the post owner
    if post.user_id != current_user.id:
        logger.warning(
            "Post update denied: user_id=%s does not own post_id=%s",
            current_user.id,
            post_id,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only update your own posts"
        )
    
    # Update post
    post.content = post_data.content
    
    await session.commit()
    await session.refresh(post)
    
    logger.info("Updated post_id=%s", post_id)
    return post


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(
    post_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """
    Delete a post.
    
    Requires authentication via JWT token.
    Only the post owner can delete their own posts.
    """
    logger.info("Deleting post_id=%s for user_id=%s", post_id, current_user.id)
    # Get post
    post = await session.get(Post, post_id)
    if not post:
        logger.warning("Post deletion failed: post_id=%s was not found", post_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found"
        )
    
    # Check if user is the post owner
    if post.user_id != current_user.id:
        logger.warning(
            "Post deletion denied: user_id=%s does not own post_id=%s",
            current_user.id,
            post_id,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only delete your own posts"
        )
    
    # Delete post
    await session.delete(post)
    await session.commit()
    
    logger.info("Deleted post_id=%s", post_id)
    return None


@router.post("/{post_id}/like", response_model=PostResponse)
async def like_post(
    post_id: int,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """
    Like a post by incrementing the likes count.
    
    Requires authentication via JWT token.
    Note: No user tracking - same user can like multiple times.
    """
    logger.info("User_id=%s liking post_id=%s", current_user.id, post_id)
    # Get post
    post = await session.get(Post, post_id)
    if not post:
        logger.warning("Post like failed: post_id=%s was not found", post_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found"
        )
    
    # Increment likes count using raw SQL for atomic operation
    await session.execute(
        text("UPDATE posts SET likes_count = likes_count + 1 WHERE id = :post_id"),
        {"post_id": post_id}
    )
    await session.commit()
    
    # Refresh to get updated values
    await session.refresh(post)
    
    logger.info("Post_id=%s liked successfully", post_id)
    return post


@router.post("/{post_id}/comments", response_model=PostResponse)
async def add_comment(
    post_id: int,
    comment_data: CommentCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user)
):
    """
    Add a comment to a post.
    
    Requires authentication via JWT token.
    Note: No user tracking - appends comment to array.
    """
    logger.info("User_id=%s adding a comment to post_id=%s", current_user.id, post_id)
    # Get post
    post = await session.get(Post, post_id)
    if not post:
        logger.warning("Comment creation failed: post_id=%s was not found", post_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Post not found"
        )
    
    # Append comment to array using raw SQL
    await session.execute(
        text("UPDATE posts SET comments = array_append(comments, :comment) WHERE id = :post_id"),
        {"comment": comment_data.comment, "post_id": post_id}
    )
    await session.commit()
    
    # Refresh to get updated values
    await session.refresh(post)
    
    logger.info("Comment added successfully to post_id=%s", post_id)
    return post
