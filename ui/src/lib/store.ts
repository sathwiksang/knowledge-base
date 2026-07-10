import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import Cookies from 'js-cookie';
import { api, User, KnowledgeBase } from './api';

interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, passwordConfirmation: string) => Promise<void>;
  logout: () => void;
  checkAuth: () => Promise<void>;
}

interface KnowledgeBaseState {
  knowledgeBases: KnowledgeBase[];
  currentKnowledgeBase: KnowledgeBase | null;
  isLoading: boolean;
  fetchKnowledgeBases: () => Promise<void>;
  setCurrentKnowledgeBase: (kb: KnowledgeBase | null) => void;
  createKnowledgeBase: (name: string, description?: string) => Promise<KnowledgeBase>;
  updateKnowledgeBase: (id: number, data: { name?: string; description?: string }) => Promise<void>;
  deleteKnowledgeBase: (id: number) => Promise<void>;
}

function getSecureCookieOptions(): Cookies.CookieAttributes {
  return {
    expires: 7,
    secure: typeof window !== 'undefined' && window.location.protocol === 'https:',
    sameSite: 'Strict' as const,
    path: '/',
  };
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      isLoading: true,
      isAuthenticated: false,

      login: async (email: string, password: string) => {
        const response = await api.login(email, password);
        Cookies.set('token', response.token, getSecureCookieOptions());
        set({
          user: response.user,
          token: response.token,
          isAuthenticated: true,
          isLoading: false,
        });
      },

      register: async (email: string, password: string, passwordConfirmation: string) => {
        const response = await api.register(email, password, passwordConfirmation);
        Cookies.set('token', response.token, getSecureCookieOptions());
        set({
          user: response.user,
          token: response.token,
          isAuthenticated: true,
          isLoading: false,
        });
      },

      logout: () => {
        Cookies.remove('token', { path: '/' });
        set({
          user: null,
          token: null,
          isAuthenticated: false,
        });
      },

      checkAuth: async () => {
        const token = Cookies.get('token');
        if (!token) {
          set({ isLoading: false, isAuthenticated: false });
          return;
        }

        try {
          const response = await api.getProfile();
          set({
            user: response.user,
            token,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch {
          Cookies.remove('token', { path: '/' });
          set({
            user: null,
            token: null,
            isAuthenticated: false,
            isLoading: false,
          });
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({ user: state.user }),
    }
  )
);

export const useKnowledgeBaseStore = create<KnowledgeBaseState>()((set) => ({
  knowledgeBases: [],
  currentKnowledgeBase: null,
  isLoading: false,

  fetchKnowledgeBases: async () => {
    set({ isLoading: true });
    try {
      const response = await api.getKnowledgeBases();
      set({ knowledgeBases: response.knowledge_bases, isLoading: false });
    } catch {
      set({ isLoading: false });
    }
  },

  setCurrentKnowledgeBase: (kb) => {
    set({ currentKnowledgeBase: kb });
  },

  createKnowledgeBase: async (name: string, description?: string) => {
    const response = await api.createKnowledgeBase(name, description);
    set((state) => ({
      knowledgeBases: [...state.knowledgeBases, response.knowledge_base],
    }));
    return response.knowledge_base;
  },

  updateKnowledgeBase: async (id: number, data: { name?: string; description?: string }) => {
    const response = await api.updateKnowledgeBase(id, data);
    set((state) => ({
      knowledgeBases: state.knowledgeBases.map((kb) =>
        kb.id === id ? response.knowledge_base : kb
      ),
      currentKnowledgeBase:
        state.currentKnowledgeBase?.id === id
          ? response.knowledge_base
          : state.currentKnowledgeBase,
    }));
  },

  deleteKnowledgeBase: async (id: number) => {
    await api.deleteKnowledgeBase(id);
    set((state) => ({
      knowledgeBases: state.knowledgeBases.filter((kb) => kb.id !== id),
      currentKnowledgeBase:
        state.currentKnowledgeBase?.id === id ? null : state.currentKnowledgeBase,
    }));
  },
}));
