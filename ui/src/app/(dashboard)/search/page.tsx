'use client';

import { useState, useEffect, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { useKnowledgeBaseStore } from '@/lib/store';
import { api, SearchResult } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Search,
  Database,
  FileText,
  Clock,
  Loader2,
  Sparkles,
} from 'lucide-react';
import { toast } from 'sonner';

export default function SearchPage() {
  const searchParams = useSearchParams();
  const { knowledgeBases } = useKnowledgeBaseStore();
  const [selectedKb, setSelectedKb] = useState<string>(
    searchParams.get('kb') || ''
  );
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [searchMeta, setSearchMeta] = useState<{
    totalChunks: number;
    searchTime: number;
  } | null>(null);

  useEffect(() => {
    const kbParam = searchParams.get('kb');
    if (kbParam) {
      setSelectedKb(kbParam);
    }
  }, [searchParams]);

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!selectedKb) {
      toast.error('Please select a knowledge base');
      return;
    }

    if (!query.trim()) {
      toast.error('Please enter a search query');
      return;
    }

    setIsSearching(true);
    setResults([]);
    setSearchMeta(null);

    try {
      const response = await api.search(Number(selectedKb), query, 10);
      setResults(response.results);
      setSearchMeta({
        totalChunks: response.total_chunks_searched,
        searchTime: response.search_time_ms,
      });
    } catch {
      toast.error('Search failed. Please try again.');
    } finally {
      setIsSearching(false);
    }
  };

  const getScoreColor = (score: number) => {
    if (score >= 0.8) return 'text-emerald-400';
    if (score >= 0.6) return 'text-blue-400';
    if (score >= 0.4) return 'text-amber-400';
    return 'text-muted-foreground';
  };

  const getScoreLabel = (score: number) => {
    if (score >= 0.8) return 'Excellent';
    if (score >= 0.6) return 'Good';
    if (score >= 0.4) return 'Fair';
    return 'Low';
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h2 className="text-xl sm:text-2xl font-bold">Semantic Search</h2>
        <p className="text-muted-foreground mt-1 text-sm sm:text-base">
          Search across your knowledge bases using AI-powered vector similarity
        </p>
      </div>

      {/* Search Form */}
      <Card className="glass-card border-border/50">
        <CardContent className="p-6">
          <form onSubmit={handleSearch} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="space-y-2">
                <Label>Knowledge Base</Label>
                <Select value={selectedKb} onValueChange={setSelectedKb}>
                  <SelectTrigger className="glass-input h-11">
                    <SelectValue placeholder="Select a knowledge base" />
                  </SelectTrigger>
                  <SelectContent className="glass-card border-border/50">
                    {knowledgeBases.map((kb) => (
                      <SelectItem key={kb.id} value={String(kb.id)}>
                        <div className="flex items-center gap-2">
                          <Database className="w-4 h-4 text-primary" />
                          {kb.name}
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="md:col-span-2 space-y-2">
                <Label>Search Query</Label>
                <Input
                  placeholder="Enter your search query..."
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  className="glass-input h-11"
                />
              </div>

              <div className="flex items-end">
                <Button
                  type="submit"
                  disabled={isSearching || !selectedKb}
                  className="w-full h-11 btn-premium bg-primary hover:bg-primary/90"
                >
                  {isSearching ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <>
                      <Search className="w-4 h-4 mr-2" />
                      Search
                    </>
                  )}
                </Button>
              </div>
            </div>
          </form>
        </CardContent>
      </Card>

      {/* Search Meta */}
      {searchMeta && (
        <div className="flex flex-wrap items-center gap-3 sm:gap-4 text-sm text-muted-foreground">
          <div className="flex items-center gap-1">
            <Sparkles className="w-4 h-4" />
            <span>
              {results.length} results from {searchMeta.totalChunks} chunks
            </span>
          </div>
          <div className="flex items-center gap-1">
            <Clock className="w-4 h-4" />
            <span>{searchMeta.searchTime.toFixed(0)}ms</span>
          </div>
        </div>
      )}

      {/* Results */}
      {isSearching ? (
        <Card className="glass-card border-border/50">
          <CardContent className="p-12 text-center">
            <Loader2 className="w-8 h-8 animate-spin text-primary mx-auto mb-4" />
            <p className="text-muted-foreground">
              Searching across your knowledge base...
            </p>
          </CardContent>
        </Card>
      ) : results.length > 0 ? (
        <ScrollArea className="h-[calc(100vh-350px)] sm:h-[calc(100vh-400px)]">
          <div className="space-y-4">
            {results.map((result, index) => (
              <Card
                key={result.chunk_id}
                className="glass-card border-border/50 card-hover stagger-item"
                style={{ animationDelay: `${index * 0.05}s` }}
              >
                <CardHeader className="pb-3">
                  <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-primary/10 border border-primary/20 text-sm font-medium text-primary flex-shrink-0">
                        {result.rank}
                      </div>
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <FileText className="w-4 h-4 text-muted-foreground flex-shrink-0" />
                          <CardTitle className="text-base truncate">
                            {result.document_title}
                          </CardTitle>
                        </div>
                      </div>
                    </div>
                    <div className="ml-11 sm:ml-0 flex-shrink-0">
                      <Badge
                        variant="outline"
                        className={`${getScoreColor(
                          result.similarity_score
                        )} border-current/20`}
                      >
                        {(result.similarity_score * 100).toFixed(1)}%{' '}
                        {getScoreLabel(result.similarity_score)}
                      </Badge>
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  <p className="text-sm text-muted-foreground leading-relaxed whitespace-pre-wrap">
                    {result.content}
                  </p>
                </CardContent>
              </Card>
            ))}
          </div>
        </ScrollArea>
      ) : searchMeta ? (
        <Card className="glass-card border-border/50">
          <CardContent className="p-12 text-center">
            <Search className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
            <h3 className="font-medium mb-2">No results found</h3>
            <p className="text-sm text-muted-foreground">
              Try adjusting your search query or adding more documents
            </p>
          </CardContent>
        </Card>
      ) : (
        <Card className="glass-card border-border/50">
          <CardContent className="p-12 text-center">
            <Search className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
            <h3 className="font-medium mb-2">Start searching</h3>
            <p className="text-sm text-muted-foreground">
              Select a knowledge base and enter your query to search
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
