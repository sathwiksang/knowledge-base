'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Database, LogIn, Menu } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ThemeToggle } from '@/components/ui/theme-toggle';
import {
  Sheet,
  SheetContent,
  SheetTitle,
} from '@/components/ui/sheet';

export default function PublicLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  return (
    <div className="min-h-screen gradient-bg grid-pattern">
      {/* Header */}
      <header className="border-b border-border/50 glass">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-14 lg:h-16 flex items-center justify-between">
          <Link href="/auth/login" className="flex items-center gap-3">
            <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-primary/10 border border-primary/20">
              <Database className="w-4 h-4 text-primary" />
            </div>
            <span className="font-semibold text-foreground tracking-tight">
              Knowledge Base
            </span>
          </Link>

          {/* Desktop nav */}
          <div className="hidden md:flex items-center gap-4">
            <Link href="/documentation">
              <Button variant="ghost" size="sm">
                Docs
              </Button>
            </Link>
            <Link href="/help">
              <Button variant="ghost" size="sm">
                Help
              </Button>
            </Link>
            <Link href="/about">
              <Button variant="ghost" size="sm">
                About
              </Button>
            </Link>
            <ThemeToggle />
            <Link href="/auth/login">
              <Button size="sm" className="btn-premium bg-primary hover:bg-primary/90">
                <LogIn className="w-4 h-4 mr-2" />
                Sign In
              </Button>
            </Link>
          </div>

          {/* Mobile hamburger */}
          <Button
            variant="ghost"
            size="icon"
            className="md:hidden"
            onClick={() => setMobileNavOpen(true)}
          >
            <Menu className="w-5 h-5" />
          </Button>
        </div>
      </header>

      {/* Mobile nav sheet */}
      <Sheet open={mobileNavOpen} onOpenChange={setMobileNavOpen}>
        <SheetContent side="right" className="w-64 p-0 glass border-border/50">
          <SheetTitle className="sr-only">Navigation Menu</SheetTitle>
          <div className="flex items-center justify-between h-14 px-4 border-b border-border/50">
            <span className="font-semibold text-foreground">Menu</span>
          </div>
          <nav className="flex flex-col p-4 gap-1">
            <Link href="/documentation" onClick={() => setMobileNavOpen(false)}>
              <Button variant="ghost" className="w-full justify-start">
                Docs
              </Button>
            </Link>
            <Link href="/help" onClick={() => setMobileNavOpen(false)}>
              <Button variant="ghost" className="w-full justify-start">
                Help
              </Button>
            </Link>
            <Link href="/about" onClick={() => setMobileNavOpen(false)}>
              <Button variant="ghost" className="w-full justify-start">
                About
              </Button>
            </Link>
            <div className="flex items-center gap-2 px-3 py-2">
              <span className="text-sm text-muted-foreground">Theme</span>
              <ThemeToggle />
            </div>
            <div className="pt-4 border-t border-border/50 mt-4">
              <Link href="/auth/login" onClick={() => setMobileNavOpen(false)}>
                <Button className="w-full btn-premium bg-primary hover:bg-primary/90">
                  <LogIn className="w-4 h-4 mr-2" />
                  Sign In
                </Button>
              </Link>
            </div>
          </nav>
        </SheetContent>
      </Sheet>

      {/* Content */}
      <main className="max-w-6xl mx-auto px-4 sm:px-6 py-6 lg:py-8">
        {children}
      </main>

      {/* Footer */}
      <footer className="border-t border-border/50 mt-auto">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 py-6 text-center text-sm text-muted-foreground">
          <p>Built with Ruby on Rails and Next.js by <span className="font-medium text-foreground">Sathwik Sangeetham</span></p>
        </div>
      </footer>
    </div>
  );
}
