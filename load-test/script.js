import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 20,
  duration: '3m',

  thresholds: {
    http_req_duration: [
      'p(90)<200',
      'p(95)<600',
      'p(99)<800',
    ],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const page = Math.floor(Math.random() * 50) + 1;
  const limit = Math.floor(Math.random() * 10) + 1;

  const url = `http://localhost:8000/posts?page=${page}&limit=${limit}`;
  const res = http.get(url);

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}