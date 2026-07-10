'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useKnowledgeBaseStore } from '@/lib/store';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Skeleton } from '@/components/ui/skeleton';
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
  Database,
  Plus,
  MoreVertical,
  Trash2,
  Edit,
  FileText,
  Loader2,
} from 'lucide-react';
import { toast } from 'sonner';
import { format } from 'date-fns';

export default function KnowledgeBasesPage() {
  const {
    knowledgeBases,
    isLoading,
    createKnowledgeBase,
    deleteKnowledgeBase,
  } = useKnowledgeBaseStore();
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isCreating, setIsCreating] = useState(false);
  const [newName, setNewName] = useState('');
  const [newDescription, setNewDescription] = useState('');

  const handleCreate = async () => {
    if (!newName.trim()) {
      toast.error('Name is required');
      return;
    }

    setIsCreating(true);
    try {
      await createKnowledgeBase(newName, newDescription);
      toast.success('Knowledge base created successfully');
      setIsCreateOpen(false);
      setNewName('');
      setNewDescription('');
    } catch {
      toast.error('Failed to create knowledge base');
    } finally {
      setIsCreating(false);
    }
  };

  const handleDelete = async (id: number, name: string) => {
    if (!confirm(`Are you sure you want to delete "${name}"? This will also delete all associated documents.`)) {
      return;
    }

    try {
      await deleteKnowledgeBase(id);
      toast.success('Knowledge base deleted');
    } catch {
      toast.error('Failed to delete knowledge base');
    }
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl sm:text-2xl font-bold">Knowledge Bases</h2>
          <p className="text-muted-foreground mt-1 text-sm sm:text-base">
            Manage your knowledge repositories
          </p>
        </div>

        <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
          <DialogTrigger asChild>
            <Button className="btn-premium bg-primary hover:bg-primary/90 w-full sm:w-auto">
              <Plus className="w-4 h-4 mr-2" />
              New Knowledge Base
            </Button>
          </DialogTrigger>
          <DialogContent className="glass-card border-border/50">
            <DialogHeader>
              <DialogTitle>Create Knowledge Base</DialogTitle>
              <DialogDescription>
                Create a new knowledge base to organize your documents
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 pt-4">
              <div className="space-y-2">
                <Label htmlFor="name">Name</Label>
                <Input
                  id="name"
                  placeholder="e.g., Product Documentation"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  className="glass-input"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="description">Description (optional)</Label>
                <Textarea
                  id="description"
                  placeholder="Brief description of this knowledge base"
                  value={newDescription}
                  onChange={(e) => setNewDescription(e.target.value)}
                  className="glass-input resize-none"
                  rows={3}
                />
              </div>
              <div className="flex justify-end gap-3 pt-4">
                <Button
                  variant="outline"
                  onClick={() => setIsCreateOpen(false)}
                  className="border-border/50"
                >
                  Cancel
                </Button>
                <Button
                  onClick={handleCreate}
                  disabled={isCreating}
                  className="btn-premium bg-primary hover:bg-primary/90"
                >
                  {isCreating ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    'Create'
                  )}
                </Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>

      {/* Knowledge Bases Grid */}
      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <Skeleton key={i} className="h-48" />
          ))}
        </div>
      ) : knowledgeBases.length === 0 ? (
        <Card className="glass-card border-border/50">
          <CardContent className="flex flex-col items-center justify-center py-16">
            <Database className="w-16 h-16 text-muted-foreground mb-4" />
            <h3 className="text-lg font-medium mb-2">No knowledge bases yet</h3>
            <p className="text-muted-foreground text-center mb-6 max-w-sm">
              Create your first knowledge base to start organizing and searching
              your documents with AI
            </p>
            <Button
              onClick={() => setIsCreateOpen(true)}
              className="btn-premium bg-primary hover:bg-primary/90"
            >
              <Plus className="w-4 h-4 mr-2" />
              Create Your First Knowledge Base
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {knowledgeBases.map((kb, index) => (
            <Card
              key={kb.id}
              className="glass-card border-border/50 card-hover stagger-item"
              style={{ animationDelay: `${index * 0.05}s` }}
            >
              <CardContent className="p-6">
                <div className="flex items-start justify-between mb-4">
                  <div className="p-3 rounded-xl bg-primary/10 border border-primary/20">
                    <Database className="w-5 h-5 text-primary" />
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 text-muted-foreground"
                      >
                        <MoreVertical className="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent
                      align="end"
                      className="glass-card border-border/50"
                    >
                      <DropdownMenuItem asChild>
                        <Link
                          href={`/knowledge-bases/${kb.id}`}
                          className="cursor-pointer"
                        >
                          <Edit className="w-4 h-4 mr-2" />
                          Manage
                        </Link>
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        onClick={() => handleDelete(kb.id, kb.name)}
                        className="text-destructive focus:text-destructive cursor-pointer"
                      >
                        <Trash2 className="w-4 h-4 mr-2" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>

                <Link href={`/knowledge-bases/${kb.id}`}>
                  <h3 className="font-semibold text-lg mb-1 hover:text-primary transition-colors">
                    {kb.name}
                  </h3>
                </Link>
                {kb.description && (
                  <p className="text-sm text-muted-foreground mb-4 line-clamp-2">
                    {kb.description}
                  </p>
                )}

                <div className="flex items-center justify-between pt-4 border-t border-border/50">
                  <div className="flex items-center gap-1 text-sm text-muted-foreground">
                    <FileText className="w-4 h-4" />
                    <span>{kb.total_documents || 0} documents</span>
                  </div>
                  <span className="text-xs text-muted-foreground">
                    {format(new Date(kb.created_at), 'MMM d, yyyy')}
                  </span>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
