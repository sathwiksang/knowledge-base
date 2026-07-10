'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import { useKnowledgeBaseStore } from '@/lib/store';
import { api, AskResponse } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Separator } from '@/components/ui/separator';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible';
import {
  MessageSquare,
  Database,
  Send,
  Loader2,
  Bot,
  User,
  FileText,
  Clock,
  ChevronDown,
  Sparkles,
  Cpu,
} from 'lucide-react';
import { toast } from 'sonner';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  sources?: AskResponse['sources'];
  meta?: {
    model: string;
    chunksUsed: number;
    totalChunks: number;
    processingTime: number;
  };
}

export default function AskPage() {
  const searchParams = useSearchParams();
  const { knowledgeBases } = useKnowledgeBaseStore();
  const [selectedKb, setSelectedKb] = useState<string>(
    searchParams.get('kb') || ''
  );
  const [question, setQuestion] = useState('');
  const [messages, setMessages] = useState<Message[]>([]);
  const [isAsking, setIsAsking] = useState(false);
  const viewportRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const kbParam = searchParams.get('kb');
    if (kbParam) {
      setSelectedKb(kbParam);
    }
  }, [searchParams]);

  const scrollToBottom = useCallback(() => {
    requestAnimationFrame(() => {
      if (viewportRef.current) {
        viewportRef.current.scrollTo({
          top: viewportRef.current.scrollHeight,
          behavior: 'smooth',
        });
      }
    });
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, isAsking, scrollToBottom]);

  const handleAsk = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!selectedKb) {
      toast.error('Please select a knowledge base');
      return;
    }

    if (!question.trim()) {
      toast.error('Please enter a question');
      return;
    }

    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: question,
    };

    setMessages((prev) => [...prev, userMessage]);
    setQuestion('');
    setIsAsking(true);

    try {
      const response = await api.ask(Number(selectedKb), userMessage.content);

      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response.answer,
        sources: response.sources,
        meta: {
          model: response.model,
          chunksUsed: response.chunks_used,
          totalChunks: response.total_chunks_searched,
          processingTime: response.processing_time_ms,
        },
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch {
      toast.error('Failed to get answer. Please try again.');
      setMessages((prev) => prev.slice(0, -1));
    } finally {
      setIsAsking(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleAsk(e);
    }
  };

  return (
    <div className="h-[calc(100vh-56px-32px)] lg:h-[calc(100vh-64px-48px)] flex flex-col animate-fade-in">
      {/* Header */}
      <div className="mb-3 lg:mb-4">
        <h2 className="text-xl sm:text-2xl font-bold">Ask AI</h2>
        <p className="text-muted-foreground mt-1 text-sm sm:text-base">
          Get AI-powered answers from your knowledge base using RAG
        </p>
      </div>

      {/* Knowledge Base Selector */}
      <Card className="glass-card border-border/50 mb-3 lg:mb-4">
        <CardContent className="p-3 lg:p-4">
          <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
            <Label className="text-muted-foreground whitespace-nowrap text-sm">
              Knowledge Base:
            </Label>
            <Select value={selectedKb} onValueChange={setSelectedKb}>
              <SelectTrigger className="glass-input w-full sm:max-w-xs">
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
        </CardContent>
      </Card>

      {/* Chat Area */}
      <Card className="glass-card border-border/50 flex-1 flex flex-col overflow-hidden min-h-0">
        <ScrollArea className="flex-1 min-h-0 p-6" viewportRef={viewportRef}>
          {messages.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-center">
              <div className="p-4 rounded-2xl bg-primary/10 border border-primary/20 mb-4">
                <MessageSquare className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-medium mb-2">Start a conversation</h3>
              <p className="text-sm text-muted-foreground max-w-sm">
                Ask questions about your documents and get AI-powered answers
                with source citations
              </p>
            </div>
          ) : (
            <div className="space-y-6">
              {messages.map((message) => (
                <div
                  key={message.id}
                  className={`flex gap-4 ${
                    message.role === 'user' ? 'justify-end' : 'justify-start'
                  }`}
                >
                  {message.role === 'assistant' && (
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 rounded-lg bg-primary/10 border border-primary/20 flex items-center justify-center">
                        <Bot className="w-4 h-4 text-primary" />
                      </div>
                    </div>
                  )}

                  <div
                    className={`max-w-[90%] sm:max-w-[80%] ${
                      message.role === 'user'
                        ? 'bg-primary/20 border border-primary/30'
                        : 'glass-card'
                    } rounded-2xl p-3 sm:p-4`}
                  >
                    <p className="whitespace-pre-wrap leading-relaxed">
                      {message.content}
                    </p>

                    {message.sources && message.sources.length > 0 && (
                      <Collapsible className="mt-4">
                        <CollapsibleTrigger asChild>
                          <Button
                            variant="ghost"
                            size="sm"
                            className="w-full justify-between text-muted-foreground hover:text-foreground"
                          >
                            <span className="flex items-center gap-2">
                              <FileText className="w-4 h-4" />
                              {message.sources.length} Sources
                            </span>
                            <ChevronDown className="w-4 h-4" />
                          </Button>
                        </CollapsibleTrigger>
                        <CollapsibleContent className="mt-2 space-y-2">
                          {message.sources.map((source, idx) => (
                            <div
                              key={idx}
                              className="p-3 rounded-lg bg-background/50 border border-border/50"
                            >
                              <div className="flex items-center justify-between mb-2">
                                <span className="text-sm font-medium">
                                  {source.document_title}
                                </span>
                                <Badge
                                  variant="outline"
                                  className="text-xs text-muted-foreground"
                                >
                                  {(source.similarity_score * 100).toFixed(0)}%
                                </Badge>
                              </div>
                              <p className="text-xs text-muted-foreground line-clamp-2">
                                {source.content}
                              </p>
                            </div>
                          ))}
                        </CollapsibleContent>
                      </Collapsible>
                    )}

                    {message.meta && (
                      <div className="flex flex-wrap items-center gap-2 sm:gap-4 mt-3 pt-3 border-t border-border/50 text-xs text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <Cpu className="w-3 h-3" />
                          {message.meta.model}
                        </span>
                        <span className="flex items-center gap-1">
                          <Sparkles className="w-3 h-3" />
                          {message.meta.chunksUsed} chunks
                        </span>
                        <span className="flex items-center gap-1">
                          <Clock className="w-3 h-3" />
                          {message.meta.processingTime.toFixed(0)}ms
                        </span>
                      </div>
                    )}
                  </div>

                  {message.role === 'user' && (
                    <div className="flex-shrink-0">
                      <div className="w-8 h-8 rounded-lg bg-muted border border-border/50 flex items-center justify-center">
                        <User className="w-4 h-4 text-muted-foreground" />
                      </div>
                    </div>
                  )}
                </div>
              ))}

              {isAsking && (
                <div className="flex gap-4 justify-start">
                  <div className="flex-shrink-0">
                    <div className="w-8 h-8 rounded-lg bg-primary/10 border border-primary/20 flex items-center justify-center">
                      <Bot className="w-4 h-4 text-primary" />
                    </div>
                  </div>
                  <div className="glass-card rounded-2xl p-4">
                    <div className="flex items-center gap-2 text-muted-foreground">
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>Thinking...</span>
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </ScrollArea>

        {/* Input Area */}
        <div className="p-3 sm:p-4 border-t border-border/50">
          <form onSubmit={handleAsk} className="flex gap-2 sm:gap-4">
            <Textarea
              placeholder="Ask a question about your documents..."
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              onKeyDown={handleKeyDown}
              disabled={!selectedKb || isAsking}
              className="glass-input resize-none min-h-[48px] max-h-[120px]"
              rows={1}
            />
            <Button
              type="submit"
              disabled={!selectedKb || !question.trim() || isAsking}
              className="px-6 btn-premium bg-primary hover:bg-primary/90"
            >
              {isAsking ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <Send className="w-4 h-4" />
              )}
            </Button>
          </form>
        </div>
      </Card>
    </div>
  );
}
