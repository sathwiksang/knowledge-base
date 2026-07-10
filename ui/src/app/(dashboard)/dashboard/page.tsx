'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useKnowledgeBaseStore } from '@/lib/store';
import { api } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Database,
  FileText,
  Search,
  MessageSquare,
  Plus,
  ArrowRight,
  CheckCircle,
  AlertCircle,
  Clock,
} from 'lucide-react';
import { format } from 'date-fns';

interface ServiceInfo {
  status: string;
  message?: string;
  adapter?: string;
  database?: string;
  base_url?: string;
}

interface HealthStatus {
  status: string;
  services: {
    api: ServiceInfo;
    database: ServiceInfo;
    ollama: ServiceInfo;
  };
}

export default function DashboardPage() {
  const { knowledgeBases, isLoading } = useKnowledgeBaseStore();
  const [health, setHealth] = useState<HealthStatus | null>(null);

  useEffect(() => {
    const checkHealth = async () => {
      try {
        const response = await api.healthCheck();
        setHealth(response);
      } catch {
        setHealth(null);
      }
    };
    checkHealth();
  }, []);

  const totalDocuments = knowledgeBases.reduce(
    (acc, kb) => acc + (kb.total_documents || 0),
    0
  );

  const stats = [
    {
      title: 'Knowledge Bases',
      value: knowledgeBases.length,
      icon: Database,
      href: '/knowledge-bases',
      color: 'text-blue-400',
      bgColor: 'bg-blue-400/10',
    },
    {
      title: 'Total Documents',
      value: totalDocuments,
      icon: FileText,
      href: '/knowledge-bases',
      color: 'text-emerald-400',
      bgColor: 'bg-emerald-400/10',
    },
    {
      title: 'Search',
      value: 'Vector',
      icon: Search,
      href: '/search',
      color: 'text-purple-400',
      bgColor: 'bg-purple-400/10',
    },
    {
      title: 'AI Assistant',
      value: 'RAG',
      icon: MessageSquare,
      href: '/ask',
      color: 'text-amber-400',
      bgColor: 'bg-amber-400/10',
    },
  ];

  const ServiceStatus = ({
    name,
    service,
  }: {
    name: string;
    service: ServiceInfo;
  }) => (
    <div className="flex items-center justify-between py-2">
      <span className="text-sm text-muted-foreground">{name}</span>
      <div className="flex items-center gap-2">
        {service?.status === 'ok' ? (
          <>
            <CheckCircle className="w-4 h-4 text-emerald-400" />
            <span className="text-sm text-emerald-400">Operational</span>
          </>
        ) : (
          <>
            <AlertCircle className="w-4 h-4 text-amber-400" />
            <span className="text-sm text-amber-400">Degraded</span>
          </>
        )}
      </div>
    </div>
  );

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat) => (
          <Link key={stat.title} href={stat.href}>
            <Card className="glass-card border-border/50 card-hover cursor-pointer">
              <CardContent className="p-6">
                <div className="flex items-start justify-between">
                  <div>
                    <p className="text-sm text-muted-foreground">{stat.title}</p>
                    <p className="text-2xl font-bold mt-1">{stat.value}</p>
                  </div>
                  <div
                    className={`p-3 rounded-xl ${stat.bgColor} border border-white/5`}
                  >
                    <stat.icon className={`w-5 h-5 ${stat.color}`} />
                  </div>
                </div>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Knowledge Bases */}
        <div className="lg:col-span-2">
          <Card className="glass-card border-border/50">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-lg font-semibold">
                Recent Knowledge Bases
              </CardTitle>
              <Link href="/knowledge-bases">
                <Button variant="ghost" size="sm" className="text-primary">
                  View All
                  <ArrowRight className="w-4 h-4 ml-1" />
                </Button>
              </Link>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <div className="space-y-4">
                  {[1, 2, 3].map((i) => (
                    <Skeleton key={i} className="h-16 w-full" />
                  ))}
                </div>
              ) : knowledgeBases.length === 0 ? (
                <div className="text-center py-12">
                  <Database className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
                  <h3 className="font-medium mb-2">No knowledge bases yet</h3>
                  <p className="text-sm text-muted-foreground mb-4">
                    Create your first knowledge base to get started
                  </p>
                  <Link href="/knowledge-bases">
                    <Button className="btn-premium bg-primary hover:bg-primary/90">
                      <Plus className="w-4 h-4 mr-2" />
                      Create Knowledge Base
                    </Button>
                  </Link>
                </div>
              ) : (
                <div className="space-y-3">
                  {knowledgeBases.slice(0, 5).map((kb, index) => (
                    <Link
                      key={kb.id}
                      href={`/knowledge-bases/${kb.id}`}
                      className="stagger-item"
                      style={{ animationDelay: `${index * 0.05}s` }}
                    >
                      <div className="flex items-center justify-between p-4 rounded-xl hover:bg-muted/30 transition-colors border border-transparent hover:border-border/50">
                        <div className="flex items-center gap-4">
                          <div className="p-2 rounded-lg bg-primary/10 border border-primary/20">
                            <Database className="w-4 h-4 text-primary" />
                          </div>
                          <div>
                            <h4 className="font-medium">{kb.name}</h4>
                            <p className="text-sm text-muted-foreground">
                              {kb.total_documents || 0} documents
                            </p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-xs text-muted-foreground">
                            {format(new Date(kb.created_at), 'MMM d, yyyy')}
                          </p>
                        </div>
                      </div>
                    </Link>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* System Status */}
        <div className="space-y-6">
          <Card className="glass-card border-border/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-lg font-semibold">
                System Status
              </CardTitle>
            </CardHeader>
            <CardContent>
              {health ? (
                <div className="space-y-1">
                  <ServiceStatus name="API Server" service={health.services.api} />
                  <ServiceStatus
                    name="Database"
                    service={health.services.database}
                  />
                  <ServiceStatus name="Ollama LLM" service={health.services.ollama} />
                </div>
              ) : (
                <div className="flex items-center gap-2 text-muted-foreground">
                  <Clock className="w-4 h-4 animate-spin" />
                  <span className="text-sm">Checking services...</span>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Quick Actions */}
          <Card className="glass-card border-border/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-lg font-semibold">
                Quick Actions
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <Link href="/knowledge-bases" className="block">
                <Button
                  variant="outline"
                  className="w-full justify-start border-border/50 hover:bg-muted/50"
                >
                  <Plus className="w-4 h-4 mr-2" />
                  New Knowledge Base
                </Button>
              </Link>
              <Link href="/search" className="block">
                <Button
                  variant="outline"
                  className="w-full justify-start border-border/50 hover:bg-muted/50"
                >
                  <Search className="w-4 h-4 mr-2" />
                  Search Documents
                </Button>
              </Link>
              <Link href="/ask" className="block">
                <Button
                  variant="outline"
                  className="w-full justify-start border-border/50 hover:bg-muted/50"
                >
                  <MessageSquare className="w-4 h-4 mr-2" />
                  Ask AI Assistant
                </Button>
              </Link>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
