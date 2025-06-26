
import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = 'http://fastapi.local:8000/api/todos/';

// GET all todos
export async function GET() {
  try {
    const res = await fetch(BACKEND_URL, { cache: 'no-store' });
    if (!res.ok) {
      return new NextResponse(JSON.stringify({ error: 'Failed to fetch from backend' }), {
        status: res.status,
      });
    }
    const data = await res.json();
    return NextResponse.json(data);
  } catch (error) {
    return new NextResponse(JSON.stringify({ error: 'Internal Server Error' }), {
      status: 500,
    });
  }
}

// POST a new todo
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const res = await fetch(BACKEND_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      return new NextResponse(JSON.stringify({ error: 'Failed to post to backend' }), {
        status: res.status,
      });
    }
    const data = await res.json();
    return NextResponse.json(data);
  } catch (error) {
    return new NextResponse(JSON.stringify({ error: 'Internal Server Error' }), {
      status: 500,
    });
  }
}
