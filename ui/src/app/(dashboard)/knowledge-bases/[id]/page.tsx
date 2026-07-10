'use client';

import { useEffect, useState, useRef, useCallback, use } from 'react';
import { useRouter } from 'next/navigation';
import { api, Document, KnowledgeBase } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Database,
  Plus,
  ArrowLeft,
  FileText,
  MoreVertical,
  Trash2,
  RefreshCw,
  Clock,
  CheckCircle,
  AlertCircle,
  Loader2,
  Search,
  MessageSquare,
} from 'lucide-react';
import { toast } from 'sonner';
import { format } from 'date-fns';
import Link from 'next/link';

const statusConfig = {
  pending: {
    label: 'Pending',
    icon: Clock,
    color: 'bg-amber-500/10 text-amber-500 border-amber-500/20',
  },
  processing: {
    label: 'Processing',
    icon: Loader2,
    color: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  },
  indexed: {
    label: 'Indexed',
    icon: CheckCircle,
    color: 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20',
  },
  failed: {
    label: 'Failed',
    icon: AlertCircle,
    color: 'bg-red-500/10 text-red-500 border-red-500/20',
  },
};

export default function KnowledgeBaseDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const router = useRouter();
  const [knowledgeBase, setKnowledgeBase] = useState<KnowledgeBase | null>(null);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [meta, setMeta] = useState<{
    total: number;
    pending: number;
    processing: number;
    indexed: number;
    failed: number;
  } | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isAdding, setIsAdding] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newContent, setNewContent] = useState('');
  const documentsRef = useRef<Document[]>([]);
  const isFetchingRef = useRef(false);

  const fetchData = useCallback(async (showError = true) => {
    if (isFetchingRef.current) return;
    isFetchingRef.current = true;
    try {
      const [kbResponse, docsResponse] = await Promise.all([
        api.getKnowledgeBase(Number(id)),
        api.getDocuments(Number(id)),
      ]);
      setKnowledgeBase(kbResponse.knowledge_base);
      setDocuments(docsResponse.documents);
      documentsRef.current = docsResponse.documents;
      setMeta(docsResponse.meta);
    } catch {
      if (showError) {
        toast.error('Failed to load knowledge base');
        router.push('/knowledge-bases');
      }
    } finally {
      setIsLoading(false);
      isFetchingRef.current = false;
    }
  }, [id, router]);

  useEffect(() => {
    fetchData();
    const interval = setInterval(() => {
      if (documentsRef.current.some((d) => d.status === 'processing' || d.status === 'pending')) {
        fetchData(false);
      }
    }, 5000);
    return () => clearInterval(interval);
  }, [fetchData]);

  const handleAddDocument = async () => {
    if (!newTitle.trim() || !newContent.trim()) {
      toast.error('Title and content are required');
      return;
    }

    setIsAdding(true);
    try {
      await api.createDocument(Number(id), newTitle, newContent);
      toast.success('Document added successfully. Processing will begin shortly.');
      setIsAddOpen(false);
      setNewTitle('');
      setNewContent('');
      fetchData();
    } catch {
      toast.error('Failed to add document');
    } finally {
      setIsAdding(false);
    }
  };

  const handleDeleteDocument = async (docId: number, title: string) => {
    if (!confirm(`Are you sure you want to delete "${title}"?`)) {
      return;
    }

    try {
      await api.deleteDocument(docId);
      toast.success('Document deleted');
      fetchData();
    } catch {
      toast.error('Failed to delete document');
    }
  };

  const handleReprocess = async (docId: number) => {
    try {
      await api.reprocessDocument(docId);
      toast.success('Document queued for reprocessing');
      fetchData();
    } catch {
      toast.error('Failed to reprocess document');
    }
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-32" />
        <Skeleton className="h-96" />
      </div>
    );
  }

  if (!knowledgeBase) {
    return null;
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="space-y-4">
        <div className="flex items-start gap-3 sm:gap-4">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => router.push('/knowledge-bases')}
            className="text-muted-foreground flex-shrink-0 mt-0.5"
          >
            <ArrowLeft className="w-4 h-4" />
          </Button>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10 border border-primary/20 flex-shrink-0">
                <Database className="w-5 h-5 text-primary" />
              </div>
              <h2 className="text-xl sm:text-2xl font-bold truncate">{knowledgeBase.name}</h2>
            </div>
            {knowledgeBase.description && (
              <p className="text-muted-foreground mt-1 ml-0 sm:ml-12 text-sm sm:text-base">
                {knowledgeBase.description}
              </p>
            )}
          </div>
        </div>

        {/* Action buttons - stack on mobile */}
        <div className="flex flex-wrap items-center gap-2 sm:gap-2">
          <Link href={`/search?kb=${id}`}>
            <Button variant="outline" size="sm" className="border-border/50">
              <Search className="w-4 h-4 mr-2" />
              Search
            </Button>
          </Link>
          <Link href={`/ask?kb=${id}`}>
            <Button variant="outline" size="sm" className="border-border/50">
              <MessageSquare className="w-4 h-4 mr-2" />
              Ask AI
            </Button>
          </Link>
          <Dialog open={isAddOpen} onOpenChange={setIsAddOpen}>
            <DialogTrigger asChild>
              <Button size="sm" className="btn-premium bg-primary hover:bg-primary/90">
                <Plus className="w-4 h-4 mr-2" />
                Add Document
              </Button>
            </DialogTrigger>
            <DialogContent className="glass-card border-border/50 max-w-[calc(100vw-2rem)] sm:max-w-2xl mx-auto">
              <DialogHeader>
                <DialogTitle>Add Document</DialogTitle>
                <DialogDescription>
                  Add a new document to this knowledge base
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4 pt-4">
                <div className="space-y-2">
                  <Label htmlFor="title">Title</Label>
                  <Input
                    id="title"
                    placeholder="Document title"
                    value={newTitle}
                    onChange={(e) => setNewTitle(e.target.value)}
                    className="glass-input"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="content">Content</Label>
                  <Textarea
                    id="content"
                    placeholder="Paste your document content here..."
                    value={newContent}
                    onChange={(e) => setNewContent(e.target.value)}
                    className="glass-input resize-none min-h-[200px]"
                  />
                </div>
                <div className="flex justify-end gap-3 pt-4">
                  <Button
                    variant="outline"
                    onClick={() => setIsAddOpen(false)}
                    className="border-border/50"
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={handleAddDocument}
                    disabled={isAdding}
                    className="btn-premium bg-primary hover:bg-primary/90"
                  >
                    {isAdding ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      'Add Document'
                    )}
                  </Button>
                </div>
              </div>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Stats */}
      {meta && (
        <div className="grid grid-cols-3 sm:grid-cols-5 gap-2 sm:gap-4">
          {[
            { label: 'Total', value: meta.total, color: 'text-foreground' },
            { label: 'Indexed', value: meta.indexed, color: 'text-emerald-400' },
            { label: 'Processing', value: meta.processing, color: 'text-blue-400' },
            { label: 'Pending', value: meta.pending, color: 'text-amber-400' },
            { label: 'Failed', value: meta.failed, color: 'text-red-400' },
          ].map((stat) => (
            <Card key={stat.label} className="glass-card border-border/50">
              <CardContent className="p-3 sm:p-4 text-center">
                <p className={`text-xl sm:text-2xl font-bold ${stat.color}`}>{stat.value}</p>
                <p className="text-xs sm:text-sm text-muted-foreground">{stat.label}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Documents Table */}
      <Card className="glass-card border-border/50">
        <CardHeader className="pb-3">
          <CardTitle className="text-lg font-semibold">Documents</CardTitle>
        </CardHeader>
        <CardContent>
          {documents.length === 0 ? (
            <div className="text-center py-12">
              <FileText className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="font-medium mb-2">No documents yet</h3>
              <p className="text-sm text-muted-foreground mb-4">
                Add your first document to start building your knowledge base
              </p>
              <Button
                onClick={() => setIsAddOpen(true)}
                className="btn-premium bg-primary hover:bg-primary/90"
              >
                <Plus className="w-4 h-4 mr-2" />
                Add Document
              </Button>
            </div>
          ) : (
            <>
              {/* Mobile: Card-based list */}
              <div className="sm:hidden space-y-3">
                {documents.map((doc) => {
                  const status = statusConfig[doc.status];
                  const StatusIcon = status.icon;
                  return (
                    <div
                      key={doc.id}
                      className="flex items-start justify-between p-3 rounded-lg border border-border/50 hover:bg-muted/30"
                    >
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2 mb-1.5">
                          <FileText className="w-4 h-4 text-muted-foreground flex-shrink-0" />
                          <span className="font-medium text-sm truncate">{doc.title}</span>
                        </div>
                        <div className="flex items-center gap-3 text-xs text-muted-foreground">
                          <Badge
                            variant="outline"
                            className={`${status.color} border text-xs`}
                          >
                            <StatusIcon
                              className={`w-3 h-3 mr-1 ${
                                doc.status === 'processing' ? 'animate-spin' : ''
                              }`}
                            />
                            {status.label}
                          </Badge>
                          <span>{doc.chunk_count || 0} chunks</span>
                          <span>{format(new Date(doc.created_at), 'MMM d')}</span>
                        </div>
                      </div>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 flex-shrink-0"
                          >
                            <MoreVertical className="w-4 h-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent
                          align="end"
                          className="glass-card border-border/50"
                        >
                          {doc.status !== 'processing' && (
                            <DropdownMenuItem
                              onClick={() => handleReprocess(doc.id)}
                              className="cursor-pointer"
                            >
                              <RefreshCw className="w-4 h-4 mr-2" />
                              Reprocess
                            </DropdownMenuItem>
                          )}
                          <DropdownMenuItem
                            onClick={() =>
                              handleDeleteDocument(doc.id, doc.title)
                            }
                            className="text-destructive focus:text-destructive cursor-pointer"
                            disabled={doc.status === 'processing'}
                          >
                            <Trash2 className="w-4 h-4 mr-2" />
                            Delete
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  );
                })}
              </div>

              {/* Desktop: Table */}
              <div className="hidden sm:block">
                <ScrollArea className="h-[400px]">
                  <Table>
                    <TableHeader>
                      <TableRow className="border-border/50 hover:bg-transparent">
                        <TableHead>Title</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Chunks</TableHead>
                        <TableHead>Created</TableHead>
                        <TableHead className="w-[50px]"></TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {documents.map((doc) => {
                        const status = statusConfig[doc.status];
                        const StatusIcon = status.icon;
                        return (
                          <TableRow
                            key={doc.id}
                            className="border-border/50 hover:bg-muted/30"
                          >
                            <TableCell>
                              <div className="flex items-center gap-3">
                                <FileText className="w-4 h-4 text-muted-foreground" />
                                <span className="font-medium">{doc.title}</span>
                              </div>
                            </TableCell>
                            <TableCell>
                              <Badge
                                variant="outline"
                                className={`${status.color} border`}
                              >
                                <StatusIcon
                                  className={`w-3 h-3 mr-1 ${
                                    doc.status === 'processing' ? 'animate-spin' : ''
                                  }`}
                                />
                                {status.label}
                              </Badge>
                            </TableCell>
                            <TableCell className="text-muted-foreground">
                              {doc.chunk_count || 0}
                            </TableCell>
                            <TableCell className="text-muted-foreground">
                              {format(new Date(doc.created_at), 'MMM d, yyyy')}
                            </TableCell>
                            <TableCell>
                              <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                  <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-8 w-8"
                                  >
                                    <MoreVertical className="w-4 h-4" />
                                  </Button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent
                                  align="end"
                                  className="glass-card border-border/50"
                                >
                                  {doc.status !== 'processing' && (
                                    <DropdownMenuItem
                                      onClick={() => handleReprocess(doc.id)}
                                      className="cursor-pointer"
                                    >
                                      <RefreshCw className="w-4 h-4 mr-2" />
                                      Reprocess
                                    </DropdownMenuItem>
                                  )}
                                  <DropdownMenuItem
                                    onClick={() =>
                                      handleDeleteDocument(doc.id, doc.title)
                                    }
                                    className="text-destructive focus:text-destructive cursor-pointer"
                                    disabled={doc.status === 'processing'}
                                  >
                                    <Trash2 className="w-4 h-4 mr-2" />
                                    Delete
                                  </DropdownMenuItem>
                                </DropdownMenuContent>
                              </DropdownMenu>
                            </TableCell>
                          </TableRow>
                        );
                      })}
                    </TableBody>
                  </Table>
                </ScrollArea>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
