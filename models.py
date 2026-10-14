from typing import List, Optional
from datetime import datetime
from sqlmodel import SQLModel, Field, Column
from sqlalchemy import ARRAY, Text


# Database Models
class User(SQLModel, table=True):
    """User model for database."""
    __tablename__ = "users"

    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, max_length=50)
    email: str = Field(unique=True, max_length=255)
    password_hash: str
    full_name: Optional[str] = Field(default=None, max_length=100)
    bio: str = Field(default="")
    avatar_url: str = Field(default="", max_length=500)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Post(SQLModel, table=True):
    """Post model for database."""
    __tablename__ = "posts"

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    content: str
    likes_count: int = Field(default=0)
    comments: List[str] = Field(default=[], sa_column=Column(ARRAY(Text)))
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


# Pydantic Schemas for Request/Response
class PostCreate(SQLModel):
    """Schema for creating a post."""
    user_id: int
    content: str = Field(max_length=280)


class PostUpdate(SQLModel):
    """Schema for updating a post."""
    content: str = Field(max_length=280)


class PostResponse(SQLModel):
    """Schema for post response."""
    id: int
    user_id: int
    content: str
    likes_count: int
    comments: List[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class PostListResponse(SQLModel):
    """Schema for paginated post list response."""
    posts: List[PostResponse]
    total: int
    page: int
    limit: int
    pages: int


class CommentCreate(SQLModel):
    """Schema for creating a comment."""
    comment: str = Field(max_length=1000)


class LoginRequest(SQLModel):
    """Schema for login request."""
    username: str
    password: str


class Token(SQLModel):
    """Schema for token response."""
    access_token: str
    token_type: str = "bearer"
