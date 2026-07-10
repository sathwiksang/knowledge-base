'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/lib/store';
import { Database } from 'lucide-react';

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const isLoading = useAuthStore((state) => state.isLoading);
  const checkAuth = useAuthStore((state) => state.checkAuth);

  useEffect(() => {
    checkAuth();
  }, []);

  useEffect(() => {
    if (!isLoading && isAuthenticated) {
      router.push('/dashboard');
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen gradient-bg grid-pattern flex items-center justify-center">
        <div className="animate-pulse">
          <Database className="w-12 h-12 text-primary" />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen gradient-bg grid-pattern flex flex-col lg:flex-row">
      {/* Left Panel - Branding (Desktop) */}
      <div className="hidden lg:flex lg:w-1/2 flex-col justify-between p-12">
        <div>
          <div className="flex items-center gap-3">
            <div className="flex items-center justify-center w-10 h-10 rounded-xl bg-primary/10 border border-primary/20">
              <Database className="w-5 h-5 text-primary" />
            </div>
            <span className="text-xl font-semibold">Knowledge Base</span>
          </div>
        </div>

        <div className="space-y-6">
          <h1 className="text-4xl font-bold leading-tight">
            Enterprise Knowledge
            <br />
            <span className="text-gradient">Management Platform</span>
          </h1>
          <p className="text-lg text-muted-foreground max-w-md">
            Harness the power of AI to search, organize, and extract insights
            from your organization&apos;s knowledge repository.
          </p>

          <div className="grid grid-cols-2 gap-4 pt-4">
            <div className="glass-card rounded-xl p-4">
              <div className="text-2xl font-bold text-primary">RAG</div>
              <div className="text-sm text-muted-foreground">
                AI-Powered Q&A
              </div>
            </div>
            <div className="glass-card rounded-xl p-4">
              <div className="text-2xl font-bold text-primary">Vector</div>
              <div className="text-sm text-muted-foreground">
                Semantic Search
              </div>
            </div>
            <div className="glass-card rounded-xl p-4">
              <div className="text-2xl font-bold text-primary">768</div>
              <div className="text-sm text-muted-foreground">
                Embedding Dims
              </div>
            </div>
            <div className="glass-card rounded-xl p-4">
              <div className="text-2xl font-bold text-primary">LLM</div>
              <div className="text-sm text-muted-foreground">
                Local Processing
              </div>
            </div>
          </div>
        </div>

        <div className="text-sm text-muted-foreground">
          Built with Ruby on Rails and Next.js
        </div>
      </div>

      {/* Mobile Branding (visible only on mobile) */}
      <div className="lg:hidden px-6 pt-8 pb-4">
        <div className="flex items-center gap-3 mb-4">
          <div className="flex items-center justify-center w-9 h-9 rounded-xl bg-primary/10 border border-primary/20">
            <Database className="w-4.5 h-4.5 text-primary" />
          </div>
          <span className="text-lg font-semibold">Knowledge Base</span>
        </div>
        <h1 className="text-2xl font-bold leading-tight mb-2">
          Enterprise Knowledge{' '}
          <span className="text-gradient">Management</span>
        </h1>
        <p className="text-sm text-muted-foreground mb-4">
          AI-powered search, organization, and insights for your knowledge repository.
        </p>
        <div className="grid grid-cols-4 gap-2">
          <div className="glass-card rounded-lg p-2.5 text-center">
            <div className="text-sm font-bold text-primary">RAG</div>
            <div className="text-[10px] text-muted-foreground">AI Q&A</div>
          </div>
          <div className="glass-card rounded-lg p-2.5 text-center">
            <div className="text-sm font-bold text-primary">Vector</div>
            <div className="text-[10px] text-muted-foreground">Search</div>
          </div>
          <div className="glass-card rounded-lg p-2.5 text-center">
            <div className="text-sm font-bold text-primary">768</div>
            <div className="text-[10px] text-muted-foreground">Dims</div>
          </div>
          <div className="glass-card rounded-lg p-2.5 text-center">
            <div className="text-sm font-bold text-primary">LLM</div>
            <div className="text-[10px] text-muted-foreground">Local</div>
          </div>
        </div>
      </div>

      {/* Right Panel - Auth Form */}
      <div className="flex-1 flex items-center justify-center p-6 lg:p-12">
        {children}
      </div>
    </div>
  );
}
