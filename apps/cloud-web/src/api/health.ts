export interface HealthResponse { status: string; service: string; database: string; timestamp: string }
const baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api';
export async function fetchHealth(): Promise<HealthResponse> {
  const response = await fetch(`${baseUrl}/health`);
  if (!response.ok) throw new Error(`API returned ${response.status}`);
  return response.json() as Promise<HealthResponse>;
}

