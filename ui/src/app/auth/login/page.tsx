'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/lib/store';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { toast } from 'sonner';
import { Loader2, ArrowRight, HelpCircle, Info, BookOpen } from 'lucide-react';
import { AxiosError } from 'axios';

export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuthStore();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await login(email, password);
      toast.success('Welcome back');
      router.push('/dashboard');
    } catch (error) {
      const axiosError = error as AxiosError<{ error: string }>;
      toast.error(axiosError.response?.data?.error || 'Invalid credentials');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="w-full max-w-md">
      <div className="glass-card rounded-2xl p-8 animate-fade-in">
        <div className="mb-8">
          <h2 className="text-2xl font-bold">Sign In</h2>
          <p className="text-muted-foreground mt-2">
            Enter your credentials to access your account
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="email">Email Address</Label>
            <Input
              id="email"
              type="email"
              placeholder="name@company.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="glass-input h-11"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              type="password"
              placeholder="Enter your password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="glass-input h-11"
            />
          </div>

          <Button
            type="submit"
            disabled={isLoading}
            className="w-full h-11 btn-premium bg-primary hover:bg-primary/90"
          >
            {isLoading ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <>
                Sign In
                <ArrowRight className="w-4 h-4 ml-2" />
              </>
            )}
          </Button>
        </form>

        <div className="mt-6 text-center text-sm text-muted-foreground">
          Don&apos;t have an account?{' '}
          <Link
            href="/auth/register"
            className="text-primary hover:text-primary/80 font-medium"
          >
            Create one
          </Link>
        </div>

        {/* Documentation, Help and About Links */}
        <div className="mt-6 pt-6 border-t border-border/50">
          <div className="flex items-center justify-center gap-6">
            <Link
              href="/documentation"
              className="flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              <BookOpen className="w-4 h-4" />
              Docs
            </Link>
            <Link
              href="/help"
              className="flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              <HelpCircle className="w-4 h-4" />
              Help
            </Link>
            <Link
              href="/about"
              className="flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              <Info className="w-4 h-4" />
              About
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
