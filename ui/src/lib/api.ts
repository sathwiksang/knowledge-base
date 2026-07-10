import axios, { AxiosInstance, AxiosError } from 'axios';
import Cookies from 'js-cookie';

// Use relative URL so requests go through Next.js rewrites (avoids mixed-content
// and CORS issues when the frontend is served over HTTPS via tunnel).
const API_BASE_URL = '';

export interface User {
  id: number;
  email: string;
  created_at: string;
}

export interface KnowledgeBase {
  id: number;
  name: string;
  description: string | null;
  total_documents: number;
  created_at: string;
  updated_at: string;
}

export interface Document {
  id: number;
  title: string;
  content: string;
  status: 'pending' | 'processing' | 'indexed' | 'failed';
  chunk_count: number;
  metadata: Record<string, unknown>;
  error_message: string | null;
  created_at: string;
  updated_at: string;
}

export interface SearchResult {
  rank: number;
  chunk_id: number;
  content: string;
  similarity_score: number;
  document_id: number;
  document_title: string;
}

export interface AskResponse {
  answer: string;
  question: string;
  sources: Array<{
    document_id: number;
    document_title: string;
    chunk_id: number;
    content: string;
    similarity_score: number;
  }>;
  model: string;
  chunks_used: number;
  total_chunks_searched: number;
  processing_time_ms: number;
}

export interface ApiError {
  error: string;
  errors?: string[];
  timestamp: string;
  request_id: string;
}

class ApiClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: `${API_BASE_URL}/api/v1`,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.client.interceptors.request.use((config) => {
      const token = Cookies.get('token');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    });

    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError<ApiError>) => {
        if (error.response?.status === 401) {
          Cookies.remove('token');
          if (typeof window !== 'undefined' && !window.location.pathname.includes('/auth')) {
            window.location.href = '/auth/login';
          }
        }
        return Promise.reject(error);
      }
    );
  }

  // Auth
  async register(email: string, password: string, passwordConfirmation: string) {
    const response = await this.client.post<{ user: User; token: string; message: string }>(
      '/auth/register',
      { email, password, password_confirmation: passwordConfirmation }
    );
    return response.data;
  }

  async login(email: string, password: string) {
    const response = await this.client.post<{ user: User; token: string }>(
      '/auth/login',
      { email, password }
    );
    return response.data;
  }

  async getProfile() {
    const response = await this.client.get<{ user: User }>('/auth/profile');
    return response.data;
  }

  // Knowledge Bases
  async getKnowledgeBases() {
    const response = await this.client.get<{ knowledge_bases: KnowledgeBase[] }>('/knowledge_bases');
    return response.data;
  }

  async getKnowledgeBase(id: number) {
    const response = await this.client.get<{ knowledge_base: KnowledgeBase }>(`/knowledge_bases/${id}`);
    return response.data;
  }

  async createKnowledgeBase(name: string, description?: string) {
    const response = await this.client.post<{ knowledge_base: KnowledgeBase; message: string }>(
      '/knowledge_bases',
      { name, description }
    );
    return response.data;
  }

  async updateKnowledgeBase(id: number, data: { name?: string; description?: string }) {
    const response = await this.client.patch<{ knowledge_base: KnowledgeBase }>(
      `/knowledge_bases/${id}`,
      data
    );
    return response.data;
  }

  async deleteKnowledgeBase(id: number) {
    const response = await this.client.delete<{ message: string }>(`/knowledge_bases/${id}`);
    return response.data;
  }

  // Documents
  async getDocuments(knowledgeBaseId: number) {
    const response = await this.client.get<{
      documents: Document[];
      meta: { total: number; pending: number; processing: number; indexed: number; failed: number };
    }>(`/knowledge_bases/${knowledgeBaseId}/documents`);
    return response.data;
  }

  async getDocument(id: number) {
    const response = await this.client.get<{ document: Document }>(`/documents/${id}`);
    return response.data;
  }

  async createDocument(knowledgeBaseId: number, title: string, content: string, metadata?: Record<string, unknown>) {
    const response = await this.client.post<{ document: Document; message: string }>(
      `/knowledge_bases/${knowledgeBaseId}/documents`,
      { title, content, metadata }
    );
    return response.data;
  }

  async deleteDocument(id: number) {
    const response = await this.client.delete<{ message: string }>(`/documents/${id}`);
    return response.data;
  }

  async reprocessDocument(id: number) {
    const response = await this.client.post<{ document: Document; message: string }>(
      `/documents/${id}/reprocess`
    );
    return response.data;
  }

  async getDocumentStatus(id: number) {
    const response = await this.client.get<{ document: Document }>(`/documents/${id}/status`);
    return response.data;
  }

  // Search
  async search(knowledgeBaseId: number, query: string, limit = 10) {
    const response = await this.client.post<{
      results: SearchResult[];
      query: string;
      total_chunks_searched: number;
      knowledge_base_id: number;
      search_time_ms: number;
    }>(`/knowledge_bases/${knowledgeBaseId}/search`, { query, limit });
    return response.data;
  }

  // Ask (RAG)
  async ask(knowledgeBaseId: number, question: string, numChunks = 5, includeSources = true) {
    const response = await this.client.post<AskResponse>(
      `/knowledge_bases/${knowledgeBaseId}/ask`,
      { question, num_chunks: numChunks, include_sources: includeSources }
    );
    return response.data;
  }

  // Health
  async healthCheck() {
    const response = await this.client.get<{
      status: string;
      timestamp: string;
      services: {
        api: { status: string; message?: string };
        database: { status: string; adapter?: string; database?: string };
        ollama: { status: string; base_url?: string };
      };
    }>('/health');
    return response.data;
  }
}

export const api = new ApiClient();
