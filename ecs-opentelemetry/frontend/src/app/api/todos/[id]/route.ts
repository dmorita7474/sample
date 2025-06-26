
import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = 'http://fastapi.local:8000/api/todos/';

// PUT (update) a todo
export async function PUT(req: NextRequest, { params }: { params: { id: string } }) {
  const id = params.id;
  try {
    const body = await req.json();
    const res = await fetch(`${BACKEND_URL}${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      return new NextResponse(JSON.stringify({ error: 'Failed to update in backend' }), {
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

// DELETE a todo
export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  const id = params.id;
  try {
    const res = await fetch(`${BACKEND_URL}${id}`, {
      method: 'DELETE',
    });
    if (!res.ok) {
      return new NextResponse(JSON.stringify({ error: 'Failed to delete in backend' }), {
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
