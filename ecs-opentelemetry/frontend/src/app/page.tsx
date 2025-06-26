
import { revalidatePath } from 'next/cache';

// --- Types ---
type Todo = {
  id: number;
  title: string;
  completed: boolean;
};

// --- API Helper Functions (Server-side) ---
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://fastapi.local:8000/api/todos/ A';

async function getTodos(): Promise<Todo[]> {
  try {
    const res = await fetch(API_URL, { cache: 'no-store' });
    if (!res.ok) {
      throw new Error(`Failed to fetch todos: ${res.statusText}`);
    }
    return res.json();
  } catch (error) {
    console.error('[GET_TODOS_ERROR]', error);
    return []; // Return empty array on error
  }
}

async function addTodo(title: string): Promise<Todo> {
  const res = await fetch(API_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title, completed: false }),
  });
  if (!res.ok) {
    throw new Error('Failed to add todo');
  }
  return res.json();
}

async function updateTodo(id: number, completed: boolean): Promise<Todo> {
  const res = await fetch(`${API_URL}${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ completed }),
  });
  if (!res.ok) {
    throw new Error('Failed to update todo');
  }
  return res.json();
}

async function deleteTodo(id: number): Promise<void> {
  const res = await fetch(`${API_URL}${id}`, {
    method: 'DELETE',
  });
  if (!res.ok) {
    throw new Error('Failed to delete todo');
  }
}

// --- Server Actions ---

async function createTodoAction(formData: FormData) {
  'use server';
  const title = formData.get('title') as string;
  if (title && title.trim()) {
    await addTodo(title.trim());
    revalidatePath('/');
  }
}

async function toggleTodoAction(id: number, completed: boolean) {
  'use server';
  await updateTodo(id, !completed);
  revalidatePath('/');
}

async function deleteTodoAction(id: number) {
  'use server';
  await deleteTodo(id);
  revalidatePath('/');
}

// --- UI Components ---

function AddTodoForm() {
  return (
    <form action={createTodoAction} className="flex items-center space-x-2">
      <input
        type="text"
        name="title"
        placeholder="Add a new todo..."
        className="flex-grow p-2 border rounded-md text-black"
        required
      />
      <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
        Add
      </button>
    </form>
  );
}

function TodoItem({ todo }: { todo: Todo }) {
  return (
    <li className="flex items-center justify-between p-3 bg-gray-800 rounded-md">
      <div className="flex items-center space-x-3">
        <input
          type="checkbox"
          checked={todo.completed}
          onChange={() => toggleTodoAction(todo.id, todo.completed)}
          className="w-5 h-5"
        />
        <span className={`${todo.completed ? 'line-through text-gray-500' : ''}`}>
          {todo.title}
        </span>
      </div>
      <form action={() => deleteTodoAction(todo.id)}>
        <button type="submit" className="px-3 py-1 text-sm text-red-400 hover:text-red-200">
          Delete
        </button>
      </form>
    </li>
  );
}

// --- Main Page Component ---

export default async function HomePage() {
  const todos = await getTodos();

  return (
    <main className="flex min-h-screen flex-col items-center p-24 bg-gray-900 text-white">
      <div className="w-full max-w-2xl">
        <h1 className="text-4xl font-bold text-center mb-8">ToDo App</h1>
        <AddTodoForm />
        <ul className="mt-8 space-y-3">
          {todos.length > 0 ? (
            todos.map((todo) => <TodoItem key={todo.id} todo={todo} />)
          ) : (
            <p className="text-center text-gray-400">No todos yet. Add one above!</p>
          )}
        </ul>
      </div>
    </main>
  );
}
