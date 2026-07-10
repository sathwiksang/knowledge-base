'use client';

import { usePathname } from 'next/navigation';
import { Bell, Search, Menu } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ThemeToggle } from '@/components/ui/theme-toggle';

const pageTitles: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/knowledge-bases': 'Knowledge Bases',
  '/search': 'Search',
  '/ask': 'Ask AI',
  '/settings': 'Settings',
};

export function Header({ onMenuClick }: { onMenuClick?: () => void }) {
  const pathname = usePathname();

  const getTitle = () => {
    if (pathname.startsWith('/knowledge-bases/') && pathname !== '/knowledge-bases') {
      return 'Knowledge Base Details';
    }
    return pageTitles[pathname] || 'Knowledge Base';
  };

  return (
    <header className="h-14 lg:h-16 border-b border-border/50 glass px-4 lg:px-6 flex items-center justify-between gap-4">
      <div className="flex items-center gap-3 min-w-0">
        {/* Mobile hamburger menu */}
        <Button
          variant="ghost"
          size="icon"
          className="lg:hidden flex-shrink-0"
          onClick={onMenuClick}
        >
          <Menu className="w-5 h-5" />
        </Button>
        <h1 className="text-lg lg:text-xl font-semibold text-foreground truncate">{getTitle()}</h1>
      </div>

      <div className="flex items-center gap-2 lg:gap-4">
        {/* Search - hidden on mobile, visible on md+ */}
        <div className="relative hidden md:block">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Quick search..."
            className="w-48 lg:w-64 pl-9 glass-input border-border/50 focus:border-primary/50"
          />
        </div>

        <ThemeToggle />

        <Button variant="ghost" size="icon" className="relative flex-shrink-0">
          <Bell className="w-4 h-4 text-muted-foreground" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-primary rounded-full" />
        </Button>
      </div>
    </header>
  );
}
