'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { cn } from '@/lib/utils';
import {
  Database,
  Search,
  MessageSquare,
  LogOut,
  ChevronLeft,
  ChevronRight,
  LayoutDashboard,
  FileText,
  HelpCircle,
  Info,
  BookOpen,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Sheet,
  SheetContent,
  SheetTitle,
} from '@/components/ui/sheet';
import { useAuthStore, useKnowledgeBaseStore } from '@/lib/store';
import { useState } from 'react';
import { toast } from 'sonner';

const mainNavItems = [
  {
    title: 'Dashboard',
    href: '/dashboard',
    icon: LayoutDashboard,
  },
  {
    title: 'Knowledge Bases',
    href: '/knowledge-bases',
    icon: Database,
  },
];

const toolNavItems = [
  {
    title: 'Search',
    href: '/search',
    icon: Search,
  },
  {
    title: 'Ask AI',
    href: '/ask',
    icon: MessageSquare,
  },
];

const supportNavItems = [
  {
    title: 'Documentation',
    href: '/documentation',
    icon: BookOpen,
  },
  {
    title: 'Help',
    href: '/help',
    icon: HelpCircle,
  },
  {
    title: 'About',
    href: '/about',
    icon: Info,
  },
];

function SidebarNav({
  collapsed,
  onNavigate,
}: {
  collapsed: boolean;
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);
  const knowledgeBases = useKnowledgeBaseStore((state) => state.knowledgeBases);

  const handleLogout = () => {
    logout();
    toast.success('Logged out successfully');
    router.push('/auth/login');
  };

  const handleClick = () => {
    onNavigate?.();
  };

  return (
    <>
      {/* Navigation */}
      <ScrollArea className="flex-1 py-4">
        <div className="px-3 space-y-6">
          {/* Main Navigation */}
          <div className="space-y-1">
            {!collapsed && (
              <p className="px-3 text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">
                Main
              </p>
            )}
            {mainNavItems.map((item) => (
              <Link key={item.href} href={item.href} onClick={handleClick}>
                <Button
                  variant="ghost"
                  className={cn(
                    'w-full justify-start gap-3 font-normal',
                    pathname === item.href
                      ? 'bg-primary/10 text-primary border border-primary/20'
                      : 'text-muted-foreground hover:text-foreground hover:bg-muted/50',
                    collapsed && 'justify-center px-2'
                  )}
                >
                  <item.icon className="w-4 h-4 flex-shrink-0" />
                  {!collapsed && <span>{item.title}</span>}
                </Button>
              </Link>
            ))}
          </div>

          {/* Tools Navigation */}
          <div className="space-y-1">
            {!collapsed && (
              <p className="px-3 text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">
                Tools
              </p>
            )}
            {toolNavItems.map((item) => (
              <Link key={item.href} href={item.href} onClick={handleClick}>
                <Button
                  variant="ghost"
                  className={cn(
                    'w-full justify-start gap-3 font-normal',
                    pathname === item.href
                      ? 'bg-primary/10 text-primary border border-primary/20'
                      : 'text-muted-foreground hover:text-foreground hover:bg-muted/50',
                    collapsed && 'justify-center px-2'
                  )}
                >
                  <item.icon className="w-4 h-4 flex-shrink-0" />
                  {!collapsed && <span>{item.title}</span>}
                </Button>
              </Link>
            ))}
          </div>

          {/* Support Navigation */}
          <div className="space-y-1">
            {!collapsed && (
              <p className="px-3 text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">
                Support
              </p>
            )}
            {supportNavItems.map((item) => (
              <Link key={item.href} href={item.href} onClick={handleClick}>
                <Button
                  variant="ghost"
                  className={cn(
                    'w-full justify-start gap-3 font-normal',
                    pathname === item.href
                      ? 'bg-primary/10 text-primary border border-primary/20'
                      : 'text-muted-foreground hover:text-foreground hover:bg-muted/50',
                    collapsed && 'justify-center px-2'
                  )}
                >
                  <item.icon className="w-4 h-4 flex-shrink-0" />
                  {!collapsed && <span>{item.title}</span>}
                </Button>
              </Link>
            ))}
          </div>

          {/* Recent Knowledge Bases */}
          {!collapsed && knowledgeBases.length > 0 && (
            <div className="space-y-1">
              <p className="px-3 text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">
                Recent
              </p>
              {knowledgeBases.slice(0, 5).map((kb) => (
                <Link key={kb.id} href={`/knowledge-bases/${kb.id}`} onClick={handleClick}>
                  <Button
                    variant="ghost"
                    className={cn(
                      'w-full justify-start gap-3 font-normal text-sm',
                      pathname === `/knowledge-bases/${kb.id}`
                        ? 'bg-primary/10 text-primary'
                        : 'text-muted-foreground hover:text-foreground hover:bg-muted/50'
                    )}
                  >
                    <FileText className="w-3.5 h-3.5 flex-shrink-0" />
                    <span className="truncate">{kb.name}</span>
                  </Button>
                </Link>
              ))}
            </div>
          )}
        </div>
      </ScrollArea>

      {/* User Section */}
      <div className="border-t border-border/50 p-3">
        <div
          className={cn(
            'flex items-center gap-3',
            collapsed && 'justify-center'
          )}
        >
          <div className="flex items-center justify-center w-8 h-8 rounded-full bg-primary/10 border border-primary/20">
            <span className="text-xs font-medium text-primary">
              {user?.email?.charAt(0).toUpperCase()}
            </span>
          </div>
          {!collapsed && (
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{user?.email}</p>
            </div>
          )}
          <Button
            variant="ghost"
            size="icon"
            className="flex-shrink-0 text-muted-foreground hover:text-destructive"
            onClick={handleLogout}
          >
            <LogOut className="w-4 h-4" />
          </Button>
        </div>
      </div>
    </>
  );
}

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div
      className={cn(
        'hidden lg:flex relative flex-col h-screen border-r border-border/50 glass transition-all duration-300',
        collapsed ? 'w-16' : 'w-64'
      )}
    >
      {/* Logo */}
      <div className="flex items-center h-16 px-4 border-b border-border/50">
        <Link href="/dashboard" className="flex items-center gap-3">
          <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-primary/10 border border-primary/20">
            <Database className="w-4 h-4 text-primary" />
          </div>
          {!collapsed && (
            <span className="font-semibold text-foreground tracking-tight">
              Knowledge Base
            </span>
          )}
        </Link>
      </div>

      {/* Toggle Button */}
      <Button
        variant="ghost"
        size="icon"
        className="absolute -right-3 top-20 w-6 h-6 rounded-full border border-border/50 bg-background shadow-md z-10"
        onClick={() => setCollapsed(!collapsed)}
      >
        {collapsed ? (
          <ChevronRight className="w-3 h-3" />
        ) : (
          <ChevronLeft className="w-3 h-3" />
        )}
      </Button>

      <SidebarNav collapsed={collapsed} />
    </div>
  );
}

export function MobileSidebar({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="left"
        className="w-72 p-0 glass border-border/50"
        showCloseButton={false}
      >
        <SheetTitle className="sr-only">Navigation Menu</SheetTitle>
        {/* Logo */}
        <div className="flex items-center h-16 px-4 border-b border-border/50">
          <Link
            href="/dashboard"
            className="flex items-center gap-3"
            onClick={() => onOpenChange(false)}
          >
            <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-primary/10 border border-primary/20">
              <Database className="w-4 h-4 text-primary" />
            </div>
            <span className="font-semibold text-foreground tracking-tight">
              Knowledge Base
            </span>
          </Link>
        </div>

        <SidebarNav collapsed={false} onNavigate={() => onOpenChange(false)} />
      </SheetContent>
    </Sheet>
  );
}
