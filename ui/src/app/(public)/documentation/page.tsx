'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Database,
  Server,
  Shield,
  Brain,
  Code,
  Layers,
  Lock,
  CheckCircle,
  GitBranch,
  HardDrive,
  Network,
  FileCode,
  Boxes,
  Workflow,
  LogIn,
  BookOpen,
  FolderTree,
  Globe,
  Key,
  Search,
  MessageSquare,
  FileText,
  Upload,
  ArrowRight,
  User,
  Calendar,
  Lightbulb,
  Play,
  Terminal,
  Cpu,
  Zap,
  ChevronRight,
  ChevronDown,
  Copy,
  Check,
  Eye,
  Settings,
  Hash,
  ArrowUpDown,
  Package,
  Folder,
  ExternalLink,
  Activity,
  Box,
  CircleDot,
  ArrowDown,
  ArrowUp,
  Sparkles,
  Fingerprint,
  Timer,
  AlertCircle,
  LayoutDashboard,
} from 'lucide-react';

// ============================================================================
// COPY BUTTON COMPONENT
// ============================================================================
function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <button
      onClick={handleCopy}
      className="absolute top-3 right-3 p-2 rounded-md bg-muted/50 hover:bg-muted transition-colors"
      title="Copy code"
    >
      {copied ? (
        <Check className="w-4 h-4 text-green-500" />
      ) : (
        <Copy className="w-4 h-4 text-muted-foreground" />
      )}
    </button>
  );
}

// ============================================================================
// CODE BLOCK COMPONENT
// ============================================================================
function CodeBlock({
  code,
  language = 'ruby',
  filename,
  showLineNumbers = true
}: {
  code: string;
  language?: string;
  filename?: string;
  showLineNumbers?: boolean;
}) {
  const lines = code.trim().split('\n');

  return (
    <div className="relative rounded-lg overflow-hidden border border-border/50 bg-zinc-950">
      {filename && (
        <div className="flex items-center gap-2 px-4 py-2 bg-zinc-900 border-b border-border/50">
          <FileCode className="w-4 h-4 text-muted-foreground" />
          <span className="text-sm text-muted-foreground font-mono">{filename}</span>
          <Badge variant="outline" className="ml-auto text-xs">{language}</Badge>
        </div>
      )}
      <CopyButton text={code} />
      <div className="overflow-x-auto">
        <pre className="p-4 text-sm font-mono whitespace-pre">
          {lines.map((line, i) => (
            <div key={i} className="flex">
              {showLineNumbers && (
                <span className="select-none text-zinc-600 w-8 text-right mr-4 flex-shrink-0">
                  {i + 1}
                </span>
              )}
              <code className="text-zinc-300">{line || ' '}</code>
            </div>
          ))}
        </pre>
      </div>
    </div>
  );
}

// ============================================================================
// COLLAPSIBLE SECTION
// ============================================================================
function CollapsibleSection({
  title,
  children,
  defaultOpen = false,
  icon: Icon
}: {
  title: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
  icon?: React.ComponentType<{ className?: string }>;
}) {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  return (
    <div className="border border-border/50 rounded-lg overflow-hidden">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center gap-3 p-4 bg-muted/30 hover:bg-muted/50 transition-colors text-left"
      >
        {Icon && <Icon className="w-5 h-5 text-primary" />}
        <span className="font-medium flex-1">{title}</span>
        {isOpen ? (
          <ChevronDown className="w-5 h-5 text-muted-foreground" />
        ) : (
          <ChevronRight className="w-5 h-5 text-muted-foreground" />
        )}
      </button>
      {isOpen && (
        <div className="p-4 border-t border-border/50">
          {children}
        </div>
      )}
    </div>
  );
}

// ============================================================================
// INFO BOX
// ============================================================================
function InfoBox({
  type = 'info',
  title,
  children
}: {
  type?: 'info' | 'warning' | 'success' | 'tip';
  title?: string;
  children: React.ReactNode;
}) {
  const styles = {
    info: 'bg-blue-500/10 border-blue-500/30 text-blue-400',
    warning: 'bg-yellow-500/10 border-yellow-500/30 text-yellow-400',
    success: 'bg-green-500/10 border-green-500/30 text-green-400',
    tip: 'bg-purple-500/10 border-purple-500/30 text-purple-400',
  };

  const icons = {
    info: Lightbulb,
    warning: AlertCircle,
    success: CheckCircle,
    tip: Sparkles,
  };

  const Icon = icons[type];

  return (
    <div className={`rounded-lg border p-4 ${styles[type]}`}>
      <div className="flex items-start gap-3">
        <Icon className="w-5 h-5 mt-0.5 flex-shrink-0" />
        <div>
          {title && <p className="font-medium mb-1">{title}</p>}
          <div className="text-sm opacity-90">{children}</div>
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// ARCHITECTURE FLOW NODE
// ============================================================================
function FlowNode({
  icon: Icon,
  title,
  subtitle,
  color,
  size = 'default'
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  subtitle?: string;
  color: string;
  size?: 'small' | 'default' | 'large';
}) {
  const sizes = {
    small: 'p-3',
    default: 'p-4',
    large: 'p-6'
  };

  return (
    <div className={`rounded-xl border-2 ${color} ${sizes[size]} bg-zinc-900/80 backdrop-blur-sm shadow-lg`}>
      <div className="flex items-center gap-3">
        <div className={`p-2 rounded-lg ${color.replace('border-', 'bg-').replace('/50', '/20')}`}>
          <Icon className={`w-5 h-5 ${color.replace('border-', 'text-').replace('/50', '')}`} />
        </div>
        <div>
          <p className="font-semibold text-white">{title}</p>
          {subtitle && <p className="text-xs text-zinc-400">{subtitle}</p>}
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// ARCHITECTURE CONNECTOR
// ============================================================================
function Connector({ direction = 'down', label }: { direction?: 'down' | 'right' | 'bidirectional'; label?: string }) {
  if (direction === 'right') {
    return (
      <div className="flex items-center gap-2 px-4">
        <div className="flex-1 h-0.5 bg-gradient-to-r from-zinc-600 to-primary/50" />
        <ArrowRight className="w-4 h-4 text-primary" />
        {label && <span className="text-xs text-zinc-500">{label}</span>}
      </div>
    );
  }

  if (direction === 'bidirectional') {
    return (
      <div className="flex flex-col items-center gap-1 py-2">
        <ArrowUp className="w-4 h-4 text-zinc-500" />
        <div className="w-0.5 h-6 bg-gradient-to-b from-primary/50 via-zinc-600 to-primary/50" />
        <ArrowDown className="w-4 h-4 text-zinc-500" />
        {label && <span className="text-xs text-zinc-500">{label}</span>}
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center gap-1 py-2">
      <div className="w-0.5 h-8 bg-gradient-to-b from-zinc-600 to-primary/50" />
      <ArrowDown className="w-4 h-4 text-primary" />
      {label && <span className="text-xs text-zinc-500">{label}</span>}
    </div>
  );
}

// ============================================================================
// METRIC CARD
// ============================================================================
function MetricCard({ label, value, icon: Icon }: { label: string; value: string; icon: React.ComponentType<{ className?: string }> }) {
  return (
    <div className="p-4 rounded-lg bg-zinc-900/50 border border-border/50">
      <div className="flex items-center gap-3">
        <Icon className="w-5 h-5 text-primary" />
        <div>
          <p className="text-2xl font-bold text-white">{value}</p>
          <p className="text-xs text-muted-foreground">{label}</p>
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// MAIN DOCUMENTATION PAGE
// ============================================================================
export default function DocumentationPage() {
  return (
    <div className="space-y-8 pb-12">
      {/* Header */}
      <div className="text-center space-y-4">
        <Badge variant="outline" className="mb-4">
          <BookOpen className="w-3 h-3 mr-1" />
          Technical Documentation v2.0
        </Badge>
        <h1 className="text-2xl sm:text-4xl font-bold gradient-text">
          Knowledge Base AI
        </h1>
        <p className="text-sm sm:text-lg text-muted-foreground max-w-2xl mx-auto">
          Complete technical documentation for the AI-powered knowledge management system.
          Built with Ruby on Rails and Next.js.
        </p>

        {/* Tech Stack Badges */}
        <div className="flex flex-wrap items-center justify-center gap-2 pt-4">
          <Badge className="bg-red-500/20 text-red-400 border-red-500/30">Ruby 3.4.8</Badge>
          <Badge className="bg-red-500/20 text-red-400 border-red-500/30">Rails 8.1.2</Badge>
          <Badge className="bg-blue-500/20 text-blue-400 border-blue-500/30">Next.js 16.1.6</Badge>
          <Badge className="bg-blue-500/20 text-blue-400 border-blue-500/30">React 19.2.3</Badge>
          <Badge className="bg-cyan-500/20 text-cyan-400 border-cyan-500/30">PostgreSQL 17</Badge>
          <Badge className="bg-purple-500/20 text-purple-400 border-purple-500/30">pgvector</Badge>
          <Badge className="bg-green-500/20 text-green-400 border-green-500/30">Ollama LLM</Badge>
        </div>
      </div>

      <Separator />

      {/* Main Tabs Navigation - Fixed proper tab structure */}
      <Tabs defaultValue="overview" className="w-full">
        <TabsList className="w-full flex flex-wrap justify-start gap-1 h-auto p-2 bg-muted/30 rounded-xl mb-8">
          <TabsTrigger value="overview" className="flex items-center gap-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground">
            <Eye className="w-4 h-4" />
            <span className="hidden sm:inline">Overview</span>
          </TabsTrigger>
          <TabsTrigger value="architecture" className="flex items-center gap-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground">
            <Network className="w-4 h-4" />
            <span className="hidden sm:inline">Architecture</span>
          </TabsTrigger>
          <TabsTrigger value="backend" className="flex items-center gap-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground">
            <Server className="w-4 h-4" />
            <span className="hidden sm:inline">Backend</span>
          </TabsTrigger>
          <TabsTrigger value="frontend" className="flex items-center gap-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground">
            <Globe className="w-4 h-4" />
            <span className="hidden sm:inline">Frontend</span>
          </TabsTrigger>
          <TabsTrigger value="database" className="flex items-center gap-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground">
            <Database className="w-4 h-4" />
            <span className="hidden sm:inline">Database</span>
          </TabsTrigger>
          <TabsTrigger value="api" className="flex items-center gap-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground">
            <Code className="w-4 h-4" />
            <span className="hidden sm:inline">API</span>
          </TabsTrigger>
          <TabsTrigger value="security" className="flex items-center gap-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground">
            <Shield className="w-4 h-4" />
            <span className="hidden sm:inline">Security</span>
          </TabsTrigger>
        </TabsList>

        {/* ================================================================== */}
        {/* TAB: OVERVIEW */}
        {/* ================================================================== */}
        <TabsContent value="overview" className="space-y-8">
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-3">
              <Eye className="w-6 h-6 text-primary" />
              Project Overview
            </h2>
            <p className="text-muted-foreground">
              Knowledge Base AI is a full-stack application enabling semantic search and AI-powered Q&A over your documents.
            </p>
          </div>

          {/* Key Metrics */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <MetricCard icon={Code} label="API Endpoints" value="18+" />
            <MetricCard icon={Database} label="Database Tables" value="4" />
            <MetricCard icon={Workflow} label="Services" value="7" />
            <MetricCard icon={Cpu} label="Vector Dims" value="768" />
          </div>

          {/* Core Features */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Sparkles className="w-5 h-5 text-yellow-500" />
                Core Features
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid md:grid-cols-2 gap-4">
                <div className="p-4 rounded-xl bg-gradient-to-br from-blue-500/10 to-transparent border border-blue-500/20">
                  <div className="flex items-center gap-3 mb-2">
                    <div className="p-2 rounded-lg bg-blue-500/20">
                      <Database className="w-5 h-5 text-blue-400" />
                    </div>
                    <h4 className="font-semibold">Knowledge Base Management</h4>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Create, organize, and manage collections of documents with full CRUD operations.
                  </p>
                </div>
                <div className="p-4 rounded-xl bg-gradient-to-br from-green-500/10 to-transparent border border-green-500/20">
                  <div className="flex items-center gap-3 mb-2">
                    <div className="p-2 rounded-lg bg-green-500/20">
                      <Upload className="w-5 h-5 text-green-400" />
                    </div>
                    <h4 className="font-semibold">Document Processing</h4>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Automatic chunking, embedding generation, and background indexing of documents.
                  </p>
                </div>
                <div className="p-4 rounded-xl bg-gradient-to-br from-purple-500/10 to-transparent border border-purple-500/20">
                  <div className="flex items-center gap-3 mb-2">
                    <div className="p-2 rounded-lg bg-purple-500/20">
                      <Search className="w-5 h-5 text-purple-400" />
                    </div>
                    <h4 className="font-semibold">Semantic Search</h4>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Vector similarity search using pgvector HNSW index for meaning-based queries.
                  </p>
                </div>
                <div className="p-4 rounded-xl bg-gradient-to-br from-pink-500/10 to-transparent border border-pink-500/20">
                  <div className="flex items-center gap-3 mb-2">
                    <div className="p-2 rounded-lg bg-pink-500/20">
                      <Brain className="w-5 h-5 text-pink-400" />
                    </div>
                    <h4 className="font-semibold">RAG-Powered Q&A</h4>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Get AI-generated answers grounded in your documents using Retrieval-Augmented Generation.
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Key Concepts */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <BookOpen className="w-5 h-5 text-primary" />
                Key Concepts Explained
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <CollapsibleSection title="Vector Embeddings - How Text Becomes Numbers" icon={Cpu} defaultOpen>
                <div className="space-y-4">
                  <p className="text-sm text-muted-foreground">
                    Embeddings convert text into numerical vectors that capture semantic meaning.
                    Similar concepts have vectors that are close together in 768-dimensional space.
                  </p>
                  <div className="rounded-xl bg-zinc-900 border border-zinc-800 p-6 overflow-x-auto">
                    <div className="flex flex-col items-center gap-4 min-w-[600px]">
                      {/* Input Text */}
                      <div className="flex items-center gap-4 w-full">
                        <div className="flex-shrink-0 w-48">
                          <div className="p-3 rounded-lg bg-blue-500/20 border border-blue-500/30 text-center">
                            <p className="text-sm font-medium text-blue-400">&quot;The cat sat on the mat&quot;</p>
                          </div>
                        </div>
                        <ArrowRight className="w-6 h-6 text-zinc-500" />
                        <div className="flex-1">
                          <div className="p-3 rounded-lg bg-purple-500/20 border border-purple-500/30">
                            <p className="text-xs font-mono text-purple-400">nomic-embed-text</p>
                          </div>
                        </div>
                        <ArrowRight className="w-6 h-6 text-zinc-500" />
                        <div className="flex-shrink-0">
                          <div className="p-3 rounded-lg bg-green-500/20 border border-green-500/30">
                            <p className="text-xs font-mono text-green-400">[0.23, -0.45, 0.89, ... 768 dims]</p>
                          </div>
                        </div>
                      </div>

                      {/* Similarity Example */}
                      <div className="w-full mt-4 p-4 rounded-lg bg-zinc-800/50 border border-zinc-700">
                        <p className="text-xs text-zinc-500 mb-3">Cosine Similarity Comparison:</p>
                        <div className="space-y-2">
                          <div className="flex items-center gap-4">
                            <span className="text-sm text-zinc-400 w-48">&quot;A cat rested on a rug&quot;</span>
                            <div className="flex-1 h-2 bg-zinc-700 rounded-full overflow-hidden">
                              <div className="h-full bg-green-500 rounded-full" style={{width: '89%'}} />
                            </div>
                            <span className="text-sm font-mono text-green-400">0.89</span>
                          </div>
                          <div className="flex items-center gap-4">
                            <span className="text-sm text-zinc-400 w-48">&quot;Dogs are great pets&quot;</span>
                            <div className="flex-1 h-2 bg-zinc-700 rounded-full overflow-hidden">
                              <div className="h-full bg-yellow-500 rounded-full" style={{width: '54%'}} />
                            </div>
                            <span className="text-sm font-mono text-yellow-400">0.54</span>
                          </div>
                          <div className="flex items-center gap-4">
                            <span className="text-sm text-zinc-400 w-48">&quot;The stock market crashed&quot;</span>
                            <div className="flex-1 h-2 bg-zinc-700 rounded-full overflow-hidden">
                              <div className="h-full bg-red-500 rounded-full" style={{width: '12%'}} />
                            </div>
                            <span className="text-sm font-mono text-red-400">0.12</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </CollapsibleSection>

              <CollapsibleSection title="RAG Pipeline - How AI Answers Questions" icon={Brain}>
                <div className="space-y-4">
                  <p className="text-sm text-muted-foreground">
                    RAG (Retrieval-Augmented Generation) enhances LLM responses with relevant context from your documents.
                  </p>
                  <div className="rounded-xl bg-zinc-900 border border-zinc-800 p-6 overflow-x-auto">
                    <div className="flex flex-col gap-4 min-w-[700px]">
                      {/* Step 1 */}
                      <div className="flex items-center gap-4">
                        <div className="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-sm">1</div>
                        <div className="flex-1 p-3 rounded-lg bg-blue-500/10 border border-blue-500/30">
                          <p className="text-sm font-medium text-blue-400">User Question</p>
                          <p className="text-xs text-zinc-400">&quot;What is the refund policy?&quot;</p>
                        </div>
                      </div>
                      <div className="flex justify-center">
                        <ArrowDown className="w-5 h-5 text-zinc-500" />
                      </div>

                      {/* Step 2 */}
                      <div className="flex items-center gap-4">
                        <div className="w-8 h-8 rounded-full bg-purple-500 flex items-center justify-center text-white font-bold text-sm">2</div>
                        <div className="flex-1 p-3 rounded-lg bg-purple-500/10 border border-purple-500/30">
                          <p className="text-sm font-medium text-purple-400">Embed Question</p>
                          <p className="text-xs text-zinc-400">Convert to vector [0.34, -0.21, ...]</p>
                        </div>
                      </div>
                      <div className="flex justify-center">
                        <ArrowDown className="w-5 h-5 text-zinc-500" />
                      </div>

                      {/* Step 3 */}
                      <div className="flex items-center gap-4">
                        <div className="w-8 h-8 rounded-full bg-cyan-500 flex items-center justify-center text-white font-bold text-sm">3</div>
                        <div className="flex-1 p-3 rounded-lg bg-cyan-500/10 border border-cyan-500/30">
                          <p className="text-sm font-medium text-cyan-400">Search Similar Chunks</p>
                          <p className="text-xs text-zinc-400">Find top 5 relevant chunks using HNSW index</p>
                        </div>
                      </div>
                      <div className="flex justify-center">
                        <ArrowDown className="w-5 h-5 text-zinc-500" />
                      </div>

                      {/* Step 4 */}
                      <div className="flex items-center gap-4">
                        <div className="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center text-white font-bold text-sm">4</div>
                        <div className="flex-1 p-3 rounded-lg bg-green-500/10 border border-green-500/30">
                          <p className="text-sm font-medium text-green-400">Build Context</p>
                          <p className="text-xs text-zinc-400">Combine retrieved chunks (max 4000 chars)</p>
                        </div>
                      </div>
                      <div className="flex justify-center">
                        <ArrowDown className="w-5 h-5 text-zinc-500" />
                      </div>

                      {/* Step 5 */}
                      <div className="flex items-center gap-4">
                        <div className="w-8 h-8 rounded-full bg-pink-500 flex items-center justify-center text-white font-bold text-sm">5</div>
                        <div className="flex-1 p-3 rounded-lg bg-pink-500/10 border border-pink-500/30">
                          <p className="text-sm font-medium text-pink-400">LLM Generation</p>
                          <p className="text-xs text-zinc-400">llama3.2:3b generates answer using context</p>
                        </div>
                      </div>
                      <div className="flex justify-center">
                        <ArrowDown className="w-5 h-5 text-zinc-500" />
                      </div>

                      {/* Result */}
                      <div className="flex items-center gap-4">
                        <div className="w-8 h-8 rounded-full bg-yellow-500 flex items-center justify-center text-white font-bold text-sm">
                          <CheckCircle className="w-4 h-4" />
                        </div>
                        <div className="flex-1 p-3 rounded-lg bg-yellow-500/10 border border-yellow-500/30">
                          <p className="text-sm font-medium text-yellow-400">Grounded Answer</p>
                          <p className="text-xs text-zinc-400">&quot;Based on the documents, refunds are processed within 30 days...&quot;</p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </CollapsibleSection>

              <CollapsibleSection title="Text Chunking - Breaking Documents Apart" icon={Boxes}>
                <div className="space-y-4">
                  <p className="text-sm text-muted-foreground">
                    Documents are split into smaller overlapping chunks for precise search and context fitting.
                  </p>
                  <div className="rounded-xl bg-zinc-900 border border-zinc-800 p-6">
                    <div className="space-y-4">
                      {/* Original Document */}
                      <div>
                        <p className="text-xs text-zinc-500 mb-2">Original Document (2000 chars)</p>
                        <div className="p-3 rounded-lg bg-zinc-800 border border-zinc-700">
                          <div className="h-16 bg-gradient-to-r from-blue-500/30 via-purple-500/30 to-pink-500/30 rounded" />
                        </div>
                      </div>

                      <div className="flex justify-center">
                        <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-zinc-800 border border-zinc-700">
                          <Boxes className="w-4 h-4 text-primary" />
                          <span className="text-xs text-zinc-400">TextChunkerService</span>
                        </div>
                      </div>

                      {/* Chunks */}
                      <div>
                        <p className="text-xs text-zinc-500 mb-2">Resulting Chunks (500 chars each, 100 overlap)</p>
                        <div className="flex gap-2 overflow-x-auto pb-2">
                          {[1, 2, 3, 4].map((i) => (
                            <div key={i} className="flex-shrink-0 w-40 p-3 rounded-lg bg-zinc-800 border border-zinc-700">
                              <div className="flex items-center gap-2 mb-2">
                                <CircleDot className="w-3 h-3 text-primary" />
                                <span className="text-xs font-medium text-zinc-300">Chunk {i}</span>
                              </div>
                              <div className="h-12 bg-gradient-to-r from-blue-500/20 to-purple-500/20 rounded mb-2" />
                              {i < 4 && (
                                <div className="h-2 bg-yellow-500/30 rounded" title="100 char overlap">
                                  <span className="text-[8px] text-yellow-500">overlap</span>
                                </div>
                              )}
                            </div>
                          ))}
                        </div>
                      </div>

                      {/* Config */}
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-2 pt-4 border-t border-zinc-700">
                        <div className="p-2 rounded bg-zinc-800 text-center">
                          <p className="text-lg font-bold text-white">500</p>
                          <p className="text-[10px] text-zinc-500">CHUNK_SIZE</p>
                        </div>
                        <div className="p-2 rounded bg-zinc-800 text-center">
                          <p className="text-lg font-bold text-white">100</p>
                          <p className="text-[10px] text-zinc-500">OVERLAP</p>
                        </div>
                        <div className="p-2 rounded bg-zinc-800 text-center">
                          <p className="text-lg font-bold text-white">50</p>
                          <p className="text-[10px] text-zinc-500">MIN_SIZE</p>
                        </div>
                        <div className="p-2 rounded bg-zinc-800 text-center">
                          <p className="text-lg font-bold text-white">2000</p>
                          <p className="text-[10px] text-zinc-500">MAX_SIZE</p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </CollapsibleSection>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ================================================================== */}
        {/* TAB: ARCHITECTURE */}
        {/* ================================================================== */}
        <TabsContent value="architecture" className="space-y-8">
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-3">
              <Network className="w-6 h-6 text-primary" />
              System Architecture
            </h2>
            <p className="text-muted-foreground">
              Professional-grade architecture diagrams showing system components and data flow.
            </p>
          </div>

          {/* Advanced SVG Architecture Diagram */}
          <Card className="glass-card overflow-hidden">
            <CardHeader className="border-b border-border/50 bg-gradient-to-r from-zinc-900 via-zinc-800 to-zinc-900">
              <CardTitle className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                Live System Architecture
              </CardTitle>
              <CardDescription>Interactive view of the complete system topology</CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              <div className="relative bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-zinc-900 via-black to-zinc-900 overflow-x-auto">
                {/* Grid Background */}
                <div className="absolute inset-0 opacity-20" style={{
                  backgroundImage: 'linear-gradient(rgba(59, 130, 246, 0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(59, 130, 246, 0.1) 1px, transparent 1px)',
                  backgroundSize: '50px 50px'
                }} />

                <div className="relative min-w-[900px] p-8">
                  {/* SVG Connection Lines */}
                  <svg className="absolute inset-0 w-full h-full pointer-events-none" style={{ zIndex: 0 }}>
                    <defs>
                      <linearGradient id="blueGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                        <stop offset="0%" stopColor="rgb(59, 130, 246)" stopOpacity="0.8" />
                        <stop offset="100%" stopColor="rgb(139, 92, 246)" stopOpacity="0.8" />
                      </linearGradient>
                      <linearGradient id="greenGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                        <stop offset="0%" stopColor="rgb(34, 197, 94)" stopOpacity="0.8" />
                        <stop offset="100%" stopColor="rgb(6, 182, 212)" stopOpacity="0.8" />
                      </linearGradient>
                      <filter id="glow">
                        <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
                        <feMerge>
                          <feMergeNode in="coloredBlur"/>
                          <feMergeNode in="SourceGraphic"/>
                        </feMerge>
                      </filter>
                    </defs>
                  </svg>

                  {/* Layer 1: User/Client */}
                  <div className="relative z-10 flex justify-center mb-6">
                    <div className="group relative">
                      <div className="absolute -inset-1 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-2xl blur opacity-30 group-hover:opacity-50 transition duration-300" />
                      <div className="relative px-8 py-4 bg-zinc-900 rounded-2xl border border-zinc-700">
                        <div className="flex items-center gap-4">
                          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center shadow-lg shadow-blue-500/25">
                            <User className="w-6 h-6 text-white" />
                          </div>
                          <div>
                            <p className="text-lg font-bold text-white">Client Browser</p>
                            <p className="text-sm text-zinc-400">Web Application User</p>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Animated Connection */}
                  <div className="flex justify-center mb-6">
                    <div className="flex flex-col items-center">
                      <div className="w-0.5 h-8 bg-gradient-to-b from-blue-500 to-purple-500" />
                      <div className="px-4 py-2 rounded-full bg-zinc-800/80 border border-zinc-600 backdrop-blur-sm">
                        <div className="flex items-center gap-2">
                          <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
                          <span className="text-xs font-mono text-zinc-300">HTTPS/443</span>
                        </div>
                      </div>
                      <div className="w-0.5 h-8 bg-gradient-to-b from-purple-500 to-blue-500" />
                    </div>
                  </div>

                  {/* Layer 2: Frontend */}
                  <div className="relative z-10 mb-6">
                    <div className="mx-auto max-w-4xl p-1 rounded-2xl bg-gradient-to-r from-blue-500/20 via-purple-500/20 to-blue-500/20">
                      <div className="p-6 bg-zinc-900/95 rounded-xl backdrop-blur-sm">
                        <div className="flex items-center gap-3 mb-4">
                          <div className="px-3 py-1 rounded-full bg-blue-500/20 text-blue-400 text-xs font-semibold tracking-wider">
                            PRESENTATION LAYER
                          </div>
                          <div className="flex-1 h-px bg-gradient-to-r from-blue-500/50 to-transparent" />
                        </div>
                        <div className="grid grid-cols-1 sm:grid-cols-5 gap-4">
                          <div className="sm:col-span-2 group relative">
                            <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-xl blur opacity-20 group-hover:opacity-40 transition" />
                            <div className="relative p-5 bg-zinc-800 rounded-xl border border-zinc-700">
                              <div className="flex items-center gap-3 mb-3">
                                <Globe className="w-8 h-8 text-blue-400" />
                                <div>
                                  <p className="font-bold text-white">Next.js 16.1.6</p>
                                  <p className="text-xs text-zinc-400">Port 3001</p>
                                </div>
                              </div>
                              <div className="flex flex-wrap gap-1">
                                <Badge className="text-[10px] bg-blue-500/10 text-blue-300 border-blue-500/30">React 19</Badge>
                                <Badge className="text-[10px] bg-blue-500/10 text-blue-300 border-blue-500/30">TypeScript</Badge>
                                <Badge className="text-[10px] bg-blue-500/10 text-blue-300 border-blue-500/30">Tailwind</Badge>
                              </div>
                            </div>
                          </div>
                          {[
                            { name: 'Dashboard', icon: LayoutDashboard, desc: 'Analytics & Overview' },
                            { name: 'Knowledge Bases', icon: Database, desc: 'CRUD Operations' },
                            { name: 'Search', icon: Search, desc: 'Semantic Queries' },
                          ].map(({ name, icon: ItemIcon, desc }) => (
                            <div key={name} className="p-4 bg-zinc-800/50 rounded-xl border border-zinc-700/50 hover:border-blue-500/30 transition-colors">
                              <ItemIcon className="w-5 h-5 text-blue-400 mb-2" />
                              <p className="text-sm font-medium text-white">{name}</p>
                              <p className="text-[10px] text-zinc-500">{desc}</p>
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Connection with Protocol Info */}
                  <div className="flex justify-center mb-6">
                    <div className="flex items-center gap-8">
                      <div className="flex flex-col items-center">
                        <div className="w-0.5 h-6 bg-gradient-to-b from-blue-500 to-red-500" />
                        <div className="px-3 py-1.5 rounded-lg bg-zinc-800 border border-zinc-600 text-[10px] font-mono text-zinc-300">
                          REST/JSON
                        </div>
                        <div className="w-0.5 h-6 bg-gradient-to-b from-red-500 to-red-600" />
                      </div>
                      <div className="flex flex-col items-center">
                        <div className="w-0.5 h-6 bg-gradient-to-b from-blue-500 to-yellow-500" />
                        <div className="px-3 py-1.5 rounded-lg bg-zinc-800 border border-yellow-500/30 text-[10px] font-mono text-yellow-400">
                          JWT Bearer
                        </div>
                        <div className="w-0.5 h-6 bg-gradient-to-b from-yellow-500 to-red-600" />
                      </div>
                      <div className="flex flex-col items-center">
                        <div className="w-0.5 h-6 bg-gradient-to-b from-blue-500 to-purple-500" />
                        <div className="px-3 py-1.5 rounded-lg bg-zinc-800 border border-zinc-600 text-[10px] font-mono text-zinc-300">
                          WebSocket
                        </div>
                        <div className="w-0.5 h-6 bg-gradient-to-b from-purple-500 to-red-600" />
                      </div>
                    </div>
                  </div>

                  {/* Layer 3: Backend API */}
                  <div className="relative z-10 mb-6">
                    <div className="mx-auto max-w-5xl p-1 rounded-2xl bg-gradient-to-r from-red-500/20 via-orange-500/20 to-red-500/20">
                      <div className="p-6 bg-zinc-900/95 rounded-xl backdrop-blur-sm">
                        <div className="flex items-center gap-3 mb-4">
                          <div className="px-3 py-1 rounded-full bg-red-500/20 text-red-400 text-xs font-semibold tracking-wider">
                            APPLICATION LAYER
                          </div>
                          <div className="flex-1 h-px bg-gradient-to-r from-red-500/50 to-transparent" />
                        </div>
                        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6">
                          {/* Rails API */}
                          <div className="group relative">
                            <div className="absolute -inset-0.5 bg-gradient-to-r from-red-500 to-orange-500 rounded-xl blur opacity-20 group-hover:opacity-40 transition" />
                            <div className="relative p-5 bg-zinc-800 rounded-xl border border-zinc-700">
                              <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-red-500 to-red-600 flex items-center justify-center shadow-lg shadow-red-500/25">
                                  <Server className="w-5 h-5 text-white" />
                                </div>
                                <div>
                                  <p className="font-bold text-white">Rails 8.1.2</p>
                                  <p className="text-xs text-zinc-400">Ruby 3.4.8</p>
                                </div>
                              </div>
                              <div className="space-y-2">
                                <p className="text-[10px] text-zinc-500 uppercase tracking-wider">Controllers</p>
                                <div className="flex flex-wrap gap-1">
                                  {['Auth', 'KB', 'Docs', 'Search', 'Ask'].map(c => (
                                    <span key={c} className="px-2 py-0.5 text-[10px] bg-red-500/10 text-red-300 rounded border border-red-500/20">{c}</span>
                                  ))}
                                </div>
                              </div>
                            </div>
                          </div>

                          {/* Services */}
                          <div className="group relative">
                            <div className="absolute -inset-0.5 bg-gradient-to-r from-purple-500 to-pink-500 rounded-xl blur opacity-20 group-hover:opacity-40 transition" />
                            <div className="relative p-5 bg-zinc-800 rounded-xl border border-zinc-700">
                              <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-purple-500 to-purple-600 flex items-center justify-center shadow-lg shadow-purple-500/25">
                                  <Workflow className="w-5 h-5 text-white" />
                                </div>
                                <div>
                                  <p className="font-bold text-white">Service Layer</p>
                                  <p className="text-xs text-zinc-400">Business Logic</p>
                                </div>
                              </div>
                              <div className="grid grid-cols-2 gap-1">
                                {['Jwt', 'Embedding', 'Chunker', 'Search', 'RAG', 'LLM'].map(s => (
                                  <span key={s} className="px-2 py-1 text-[10px] bg-purple-500/10 text-purple-300 rounded text-center border border-purple-500/20">{s}</span>
                                ))}
                              </div>
                            </div>
                          </div>

                          {/* Middleware */}
                          <div className="group relative">
                            <div className="absolute -inset-0.5 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-xl blur opacity-20 group-hover:opacity-40 transition" />
                            <div className="relative p-5 bg-zinc-800 rounded-xl border border-zinc-700">
                              <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-yellow-500 to-yellow-600 flex items-center justify-center shadow-lg shadow-yellow-500/25">
                                  <Shield className="w-5 h-5 text-white" />
                                </div>
                                <div>
                                  <p className="font-bold text-white">Middleware</p>
                                  <p className="text-xs text-zinc-400">Security & Auth</p>
                                </div>
                              </div>
                              <div className="space-y-1">
                                {['Rack::Attack', 'JWT Auth', 'CORS'].map(m => (
                                  <div key={m} className="flex items-center gap-2">
                                    <div className="w-1.5 h-1.5 rounded-full bg-yellow-400" />
                                    <span className="text-xs text-zinc-400">{m}</span>
                                  </div>
                                ))}
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Connection Lines */}
                  <div className="flex justify-around mb-6 px-12">
                    {[
                      { label: 'ActiveRecord ORM', color: 'cyan' },
                      { label: 'Solid Queue', color: 'yellow' },
                      { label: 'HTTP/11434', color: 'green' },
                    ].map(({ label, color }) => (
                      <div key={label} className="flex flex-col items-center">
                        <div className={`w-0.5 h-8 bg-gradient-to-b from-red-500 to-${color}-500`} />
                        <div className={`px-3 py-1.5 rounded-lg bg-zinc-800 border border-${color}-500/30`}>
                          <span className={`text-[10px] font-mono text-${color}-400`}>{label}</span>
                        </div>
                        <div className={`w-0.5 h-8 bg-gradient-to-b from-${color}-500 to-${color}-600`} />
                      </div>
                    ))}
                  </div>

                  {/* Layer 4: Data & AI */}
                  <div className="relative z-10">
                    <div className="mx-auto max-w-5xl p-1 rounded-2xl bg-gradient-to-r from-cyan-500/20 via-green-500/20 to-cyan-500/20">
                      <div className="p-6 bg-zinc-900/95 rounded-xl backdrop-blur-sm">
                        <div className="flex items-center gap-3 mb-4">
                          <div className="px-3 py-1 rounded-full bg-cyan-500/20 text-cyan-400 text-xs font-semibold tracking-wider">
                            DATA & AI LAYER
                          </div>
                          <div className="flex-1 h-px bg-gradient-to-r from-cyan-500/50 to-transparent" />
                        </div>
                        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6">
                          {/* PostgreSQL */}
                          <div className="group relative">
                            <div className="absolute -inset-0.5 bg-gradient-to-r from-cyan-500 to-blue-500 rounded-xl blur opacity-20 group-hover:opacity-40 transition" />
                            <div className="relative p-5 bg-zinc-800 rounded-xl border border-zinc-700">
                              <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-cyan-500 to-cyan-600 flex items-center justify-center shadow-lg shadow-cyan-500/25">
                                  <Database className="w-5 h-5 text-white" />
                                </div>
                                <div>
                                  <p className="font-bold text-white">PostgreSQL 17</p>
                                  <p className="text-xs text-cyan-400">+ pgvector</p>
                                </div>
                              </div>
                              <div className="grid grid-cols-2 gap-1">
                                {['users', 'knowledge_bases', 'documents', 'chunks'].map(t => (
                                  <div key={t} className="flex items-center gap-1.5 px-2 py-1 bg-cyan-500/10 rounded border border-cyan-500/20">
                                    <div className="w-1.5 h-1.5 rounded-full bg-cyan-400" />
                                    <span className="text-[10px] text-zinc-300">{t}</span>
                                  </div>
                                ))}
                              </div>
                            </div>
                          </div>

                          {/* Solid Queue */}
                          <div className="group relative">
                            <div className="absolute -inset-0.5 bg-gradient-to-r from-yellow-500 to-amber-500 rounded-xl blur opacity-20 group-hover:opacity-40 transition" />
                            <div className="relative p-5 bg-zinc-800 rounded-xl border border-zinc-700">
                              <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-yellow-500 to-amber-500 flex items-center justify-center shadow-lg shadow-yellow-500/25">
                                  <Activity className="w-5 h-5 text-white" />
                                </div>
                                <div>
                                  <p className="font-bold text-white">Solid Queue</p>
                                  <p className="text-xs text-yellow-400">Background Jobs</p>
                                </div>
                              </div>
                              <div className="space-y-1.5">
                                <div className="flex items-center justify-between p-2 bg-yellow-500/10 rounded border border-yellow-500/20">
                                  <span className="text-[10px] text-zinc-300">DocumentProcessing</span>
                                  <Badge className="text-[8px] bg-green-500/20 text-green-400">Active</Badge>
                                </div>
                                <div className="flex items-center justify-between p-2 bg-yellow-500/10 rounded border border-yellow-500/20">
                                  <span className="text-[10px] text-zinc-300">EmbeddingGeneration</span>
                                  <Badge className="text-[8px] bg-green-500/20 text-green-400">Active</Badge>
                                </div>
                              </div>
                            </div>
                          </div>

                          {/* Ollama */}
                          <div className="group relative">
                            <div className="absolute -inset-0.5 bg-gradient-to-r from-green-500 to-emerald-500 rounded-xl blur opacity-20 group-hover:opacity-40 transition" />
                            <div className="relative p-5 bg-zinc-800 rounded-xl border border-zinc-700">
                              <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-green-500 to-emerald-500 flex items-center justify-center shadow-lg shadow-green-500/25">
                                  <Brain className="w-5 h-5 text-white" />
                                </div>
                                <div>
                                  <p className="font-bold text-white">Ollama</p>
                                  <p className="text-xs text-green-400">Local LLM</p>
                                </div>
                              </div>
                              <div className="space-y-1.5">
                                <div className="flex items-center justify-between p-2 bg-green-500/10 rounded border border-green-500/20">
                                  <span className="text-[10px] text-zinc-300">llama3.2:3b</span>
                                  <span className="text-[8px] text-zinc-500">Chat</span>
                                </div>
                                <div className="flex items-center justify-between p-2 bg-green-500/10 rounded border border-green-500/20">
                                  <span className="text-[10px] text-zinc-300">nomic-embed-text</span>
                                  <span className="text-[8px] text-zinc-500">768d</span>
                                </div>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Advanced Request Flow Diagram */}
          <Card className="glass-card overflow-hidden">
            <CardHeader className="border-b border-border/50">
              <CardTitle className="flex items-center gap-2">
                <Workflow className="w-5 h-5 text-primary" />
                Document Processing Pipeline
              </CardTitle>
              <CardDescription>Real-time visualization of the document indexing workflow</CardDescription>
            </CardHeader>
            <CardContent className="p-0">
              <div className="relative bg-gradient-to-br from-zinc-900 via-zinc-950 to-black p-8 overflow-x-auto">
                {/* Background Pattern */}
                <div className="absolute inset-0 opacity-10" style={{
                  backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%239C92AC' fill-opacity='0.1'%3E%3Ccircle cx='30' cy='30' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`
                }} />

                <div className="relative min-w-[800px]">
                  {/* Pipeline Steps */}
                  <div className="flex items-stretch justify-between gap-4">
                    {[
                      { step: 1, title: 'Upload', desc: 'Document submitted via API', icon: Upload, color: 'blue', timing: '~10ms' },
                      { step: 2, title: 'Queue', desc: 'Job enqueued for processing', icon: Activity, color: 'yellow', timing: '~5ms' },
                      { step: 3, title: 'Chunk', desc: 'Split into 500-char segments', icon: Boxes, color: 'purple', timing: '~50ms' },
                      { step: 4, title: 'Embed', desc: 'Generate 768-dim vectors', icon: Cpu, color: 'cyan', timing: '~200ms/chunk' },
                      { step: 5, title: 'Index', desc: 'Store in HNSW index', icon: Database, color: 'green', timing: '~20ms' },
                      { step: 6, title: 'Ready', desc: 'Available for search', icon: CheckCircle, color: 'emerald', timing: 'Complete' },
                    ].map(({ step, title, desc, icon: StepIcon, color, timing }, index) => (
                      <div key={step} className="flex items-center flex-1">
                        <div className="flex-1">
                          <div className={`relative p-4 rounded-xl bg-gradient-to-b from-${color}-500/10 to-transparent border border-${color}-500/30 hover:border-${color}-500/50 transition-colors`}>
                            {/* Step Number */}
                            <div className={`absolute -top-3 -left-3 w-8 h-8 rounded-full bg-gradient-to-br from-${color}-500 to-${color}-600 flex items-center justify-center text-white font-bold text-sm shadow-lg shadow-${color}-500/30`}>
                              {step}
                            </div>

                            {/* Content */}
                            <div className="pt-2">
                              <StepIcon className={`w-8 h-8 text-${color}-400 mb-3`} />
                              <p className="font-semibold text-white mb-1">{title}</p>
                              <p className="text-xs text-zinc-400 mb-2">{desc}</p>
                              <div className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-${color}-500/20 border border-${color}-500/30`}>
                                <Timer className="w-3 h-3 text-zinc-400" />
                                <span className={`text-[10px] font-mono text-${color}-400`}>{timing}</span>
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* Connector Arrow */}
                        {index < 5 && (
                          <div className="flex items-center px-2">
                            <div className={`w-8 h-0.5 bg-gradient-to-r from-${color}-500 to-zinc-700`} />
                            <ChevronRight className="w-4 h-4 text-zinc-500 -ml-1" />
                          </div>
                        )}
                      </div>
                    ))}
                  </div>

                  {/* Stats Bar */}
                  <div className="mt-8 p-4 rounded-xl bg-zinc-800/50 border border-zinc-700">
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                      {[
                        { label: 'Avg. Processing Time', value: '~500ms', color: 'blue' },
                        { label: 'Chunks per Document', value: '~4-8', color: 'purple' },
                        { label: 'Vector Dimensions', value: '768', color: 'cyan' },
                        { label: 'Index Type', value: 'HNSW', color: 'green' },
                      ].map(({ label, value, color }) => (
                        <div key={label} className="text-center">
                          <p className={`text-2xl font-bold text-${color}-400`}>{value}</p>
                          <p className="text-xs text-zinc-500">{label}</p>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Folder Structure */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <FolderTree className="w-5 h-5 text-primary" />
                Project Folder Structure
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid lg:grid-cols-2 gap-6">
                <div>
                  <h4 className="font-medium mb-3 flex items-center gap-2">
                    <Server className="w-4 h-4 text-red-400" />
                    Backend (Rails API)
                  </h4>
                  <CodeBlock
                    language="text"
                    showLineNumbers={false}
                    code={`knowledge_base_api/
├── app/
│   ├── controllers/api/v1/
│   │   ├── auth_controller.rb
│   │   ├── knowledge_bases_controller.rb
│   │   ├── documents_controller.rb
│   │   ├── search_controller.rb
│   │   └── ask_controller.rb
│   ├── models/
│   │   ├── user.rb
│   │   ├── knowledge_base.rb
│   │   ├── document.rb
│   │   └── chunk.rb
│   ├── services/
│   │   ├── jwt_service.rb
│   │   ├── embedding_service.rb
│   │   ├── text_chunker_service.rb
│   │   ├── search_service.rb
│   │   ├── rag_service.rb
│   │   └── llm_service.rb
│   └── jobs/
│       └── document_processing_job.rb
├── lib/clients/
│   └── ollama_client.rb
└── db/
    └── schema.rb`}
                  />
                </div>
                <div>
                  <h4 className="font-medium mb-3 flex items-center gap-2">
                    <Globe className="w-4 h-4 text-blue-400" />
                    Frontend (Next.js)
                  </h4>
                  <CodeBlock
                    language="text"
                    showLineNumbers={false}
                    code={`knowledge_base_ui/
├── src/
│   ├── app/
│   │   ├── (dashboard)/
│   │   │   ├── dashboard/
│   │   │   ├── knowledge-bases/
│   │   │   ├── search/
│   │   │   └── ask/
│   │   ├── (public)/
│   │   │   ├── documentation/
│   │   │   ├── help/
│   │   │   └── about/
│   │   └── auth/
│   │       ├── login/
│   │       └── register/
│   ├── components/
│   │   ├── ui/  (shadcn)
│   │   └── layout/
│   │       └── sidebar.tsx
│   └── lib/
│       ├── api.ts
│       ├── store.ts
│       └── utils.ts
└── tailwind.config.js`}
                  />
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ================================================================== */}
        {/* TAB: BACKEND */}
        {/* ================================================================== */}
        <TabsContent value="backend" className="space-y-8">
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-3">
              <Server className="w-6 h-6 text-primary" />
              Backend Implementation
            </h2>
            <p className="text-muted-foreground">
              Complete Ruby on Rails source code from the actual implementation.
            </p>
          </div>

          {/* Models */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Database className="w-5 h-5 text-blue-400" />
                ActiveRecord Models
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <CollapsibleSection title="User Model" icon={User} defaultOpen>
                <CodeBlock
                  filename="app/models/user.rb"
                  language="ruby"
                  code={`class User < ApplicationRecord
  has_secure_password

  has_many :knowledge_bases, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 },
                       if: -> { new_record? || !password.nil? }

  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase
  end
end`}
                />
              </CollapsibleSection>

              <CollapsibleSection title="KnowledgeBase Model" icon={Database}>
                <CodeBlock
                  filename="app/models/knowledge_base.rb"
                  language="ruby"
                  code={`class KnowledgeBase < ApplicationRecord
  belongs_to :user
  has_many :documents, dependent: :destroy

  validates :name, presence: true,
                   length: { maximum: 255 },
                   uniqueness: { scope: :user_id,
                                 message: "already exists for this user" }
  validates :description, length: { maximum: 1000 }

  def total_documents
    documents.count
  end

  def indexed_documents
    documents.where(status: "indexed").count
  end

  def total_chunks
    Chunk.joins(:document)
         .where(documents: { knowledge_base_id: id }).count
  end
end`}
                />
              </CollapsibleSection>

              <CollapsibleSection title="Document Model" icon={FileText}>
                <CodeBlock
                  filename="app/models/document.rb"
                  language="ruby"
                  code={`class Document < ApplicationRecord
  belongs_to :knowledge_base
  has_many :chunks, dependent: :destroy

  STATUSES = %w[pending processing indexed failed].freeze

  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :indexed, -> { where(status: "indexed") }
  scope :failed, -> { where(status: "failed") }

  def mark_processing!
    update!(status: "processing")
  end

  def mark_indexed!
    update!(status: "indexed")
  end

  def mark_failed!(error_message = nil)
    update!(status: "failed", metadata: metadata.merge("error" => error_message))
  end
end`}
                />
              </CollapsibleSection>

              <CollapsibleSection title="Chunk Model (Vector Embeddings)" icon={Cpu}>
                <CodeBlock
                  filename="app/models/chunk.rb"
                  language="ruby"
                  code={`class Chunk < ApplicationRecord
  belongs_to :document

  # Enable neighbor gem for vector search
  has_neighbors :embedding

  validates :content, presence: true
  validates :chunk_index, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            uniqueness: { scope: :document_id }

  scope :for_knowledge_base, ->(kb_id) {
    joins(:document).where(documents: { knowledge_base_id: kb_id })
  }

  def self.search_similar(query_embedding, knowledge_base_id:, limit: 5)
    for_knowledge_base(knowledge_base_id)
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)
  end
end`}
                />
              </CollapsibleSection>
            </CardContent>
          </Card>

          {/* Services */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Workflow className="w-5 h-5 text-purple-400" />
                Service Classes
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <CollapsibleSection title="JwtService - Authentication" icon={Key} defaultOpen>
                <CodeBlock
                  filename="app/services/jwt_service.rb"
                  language="ruby"
                  code={`class JwtService
  SECRET_KEY = ENV.fetch("JWT_SECRET_KEY") { Rails.application.credentials.secret_key_base }
  ALGORITHM = "HS256".freeze
  EXPIRATION_TIME = 24.hours

  class << self
    def encode(payload)
      payload[:exp] = EXPIRATION_TIME.from_now.to_i
      payload[:iat] = Time.current.to_i
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM })
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature
      raise AuthenticationError, "Token has expired"
    rescue JWT::DecodeError => e
      raise AuthenticationError, "Invalid token: #{e.message}"
    end
  end

  class AuthenticationError < StandardError; end
end`}
                />
              </CollapsibleSection>

              <CollapsibleSection title="EmbeddingService - Vector Generation" icon={Cpu}>
                <CodeBlock
                  filename="app/services/embedding_service.rb"
                  language="ruby"
                  code={`class EmbeddingService
  EMBEDDING_DIMENSIONS = 768  # nomic-embed-text produces 768-dim vectors
  MAX_TEXT_LENGTH = 8000
  BATCH_SIZE = 10

  class EmbeddingError < StandardError; end

  def initialize(client: nil)
    @client = client || Clients::OllamaClient.new
  end

  def generate(text)
    return nil if text.blank?
    normalized_text = normalize_text(text)
    return nil if normalized_text.blank?

    embedding = @client.embed(normalized_text)
    validate_embedding!(embedding)
    embedding
  rescue Clients::OllamaClient::OllamaError => e
    raise EmbeddingError, "Failed to generate embedding: #{e.message}"
  end

  def cosine_similarity(embedding1, embedding2)
    return 0.0 if embedding1.blank? || embedding2.blank?

    dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
    magnitude1 = Math.sqrt(embedding1.sum { |x| x**2 })
    magnitude2 = Math.sqrt(embedding2.sum { |x| x**2 })

    return 0.0 if magnitude1.zero? || magnitude2.zero?
    dot_product / (magnitude1 * magnitude2)
  end
end`}
                />
              </CollapsibleSection>

              <CollapsibleSection title="SearchService - Semantic Search" icon={Search}>
                <CodeBlock
                  filename="app/services/search_service.rb"
                  language="ruby"
                  code={`class SearchService
  DEFAULT_LIMIT = 5
  MAX_LIMIT = 20
  MIN_QUERY_LENGTH = 2
  MAX_QUERY_LENGTH = 1000

  class SearchError < StandardError; end
  class InvalidQueryError < SearchError; end

  def initialize(embedding_service: nil)
    @embedding_service = embedding_service || EmbeddingService.new
  end

  def search(query:, knowledge_base:, limit: DEFAULT_LIMIT)
    validate_query!(query)
    limit = [limit.to_i, MAX_LIMIT].min
    limit = DEFAULT_LIMIT if limit < 1

    query_embedding = @embedding_service.generate(query)

    chunks = Chunk.search_similar(
      query_embedding,
      knowledge_base_id: knowledge_base.id,
      limit: limit
    )

    format_results(chunks, query_embedding)
  end

  private

  def validate_query!(query)
    raise InvalidQueryError, "Query too short" if query.length < MIN_QUERY_LENGTH
    raise InvalidQueryError, "Query too long" if query.length > MAX_QUERY_LENGTH
  end
end`}
                />
              </CollapsibleSection>

              <CollapsibleSection title="RagService - AI Q&A" icon={Brain}>
                <CodeBlock
                  filename="app/services/rag_service.rb"
                  language="ruby"
                  code={`class RagService
  DEFAULT_CHUNKS = 5
  MIN_SIMILARITY = 0.3
  MAX_CONTEXT_LENGTH = 4000

  class RagError < StandardError; end
  class InsufficientContextError < RagError; end

  def initialize(search_service: nil, llm_service: nil)
    @search_service = search_service || SearchService.new
    @llm_service = llm_service || LlmService.new
  end

  def ask(question:, knowledge_base:, num_chunks: DEFAULT_CHUNKS)
    search_results = @search_service.search(
      query: question,
      knowledge_base: knowledge_base,
      limit: num_chunks
    )

    relevant_chunks = search_results.select { |r| r[:similarity] >= MIN_SIMILARITY }

    if relevant_chunks.empty?
      raise InsufficientContextError, "No relevant context found"
    end

    context = build_context(relevant_chunks)

    answer = @llm_service.generate_rag_response(
      question: question,
      context: context
    )

    { answer: answer, sources: relevant_chunks.map { |c| c[:document_title] }.uniq }
  end
end`}
                />
              </CollapsibleSection>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ================================================================== */}
        {/* TAB: FRONTEND */}
        {/* ================================================================== */}
        <TabsContent value="frontend" className="space-y-8">
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-3">
              <Globe className="w-6 h-6 text-primary" />
              Frontend Implementation
            </h2>
            <p className="text-muted-foreground">
              TypeScript interfaces, Zustand stores, and API client.
            </p>
          </div>

          <Card className="glass-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Code className="w-5 h-5 text-blue-400" />
                TypeScript Interfaces
              </CardTitle>
            </CardHeader>
            <CardContent>
              <CodeBlock
                filename="src/lib/api.ts"
                language="typescript"
                code={`// User Types
export interface User {
  id: number;
  email: string;
  created_at: string;
}

// Knowledge Base Types
export interface KnowledgeBase {
  id: number;
  name: string;
  description: string | null;
  created_at: string;
  updated_at: string;
  documents_count: number;
  indexed_documents_count: number;
  chunks_count: number;
}

// Document Types
export interface Document {
  id: number;
  title: string;
  content: string;
  status: 'pending' | 'processing' | 'indexed' | 'failed';
  chunks_count: number;
  metadata: Record<string, unknown>;
}

// Search Result Types
export interface SearchResult {
  chunk_id: number;
  content: string;
  similarity: number;
  document_id: number;
  document_title: string;
}

// Ask (RAG) Response
export interface AskResponse {
  data: {
    answer: string;
    sources: string[];
    chunks_used: number;
    question: string;
  };
}`}
              />
            </CardContent>
          </Card>

          <Card className="glass-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Layers className="w-5 h-5 text-purple-400" />
                Zustand State Management
              </CardTitle>
            </CardHeader>
            <CardContent>
              <CodeBlock
                filename="src/lib/store.ts"
                language="typescript"
                code={`import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { api, User, KnowledgeBase } from './api';

// Auth Store
interface AuthState {
  token: string | null;
  user: User | null;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, passwordConfirmation: string) => Promise<void>;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      user: null,
      isAuthenticated: false,

      login: async (email, password) => {
        const response = await api.post('/auth/login', { email, password });
        const { token, user } = response.data.data;
        set({ token, user, isAuthenticated: true });
      },

      register: async (email, password, passwordConfirmation) => {
        const response = await api.post('/auth/register', {
          email,
          password,
          password_confirmation: passwordConfirmation,
        });
        const { token, user } = response.data.data;
        set({ token, user, isAuthenticated: true });
      },

      logout: () => set({ token: null, user: null, isAuthenticated: false }),
    }),
    { name: 'auth-storage' }
  )
);

// Knowledge Base Store
interface KnowledgeBaseState {
  knowledgeBases: KnowledgeBase[];
  currentKnowledgeBase: KnowledgeBase | null;
  isLoading: boolean;
  fetchKnowledgeBases: () => Promise<void>;
  createKnowledgeBase: (name: string, description?: string) => Promise<KnowledgeBase>;
  deleteKnowledgeBase: (id: number) => Promise<void>;
}

export const useKnowledgeBaseStore = create<KnowledgeBaseState>((set) => ({
  knowledgeBases: [],
  currentKnowledgeBase: null,
  isLoading: false,

  fetchKnowledgeBases: async () => {
    set({ isLoading: true });
    const response = await api.get('/knowledge_bases');
    set({ knowledgeBases: response.data.data, isLoading: false });
  },

  createKnowledgeBase: async (name, description) => {
    const response = await api.post('/knowledge_bases', { name, description });
    const newKb = response.data.data;
    set((state) => ({ knowledgeBases: [...state.knowledgeBases, newKb] }));
    return newKb;
  },

  deleteKnowledgeBase: async (id) => {
    await api.delete(\`/knowledge_bases/\${id}\`);
    set((state) => ({
      knowledgeBases: state.knowledgeBases.filter((kb) => kb.id !== id)
    }));
  },
}));`}
              />
            </CardContent>
          </Card>
        </TabsContent>

        {/* ================================================================== */}
        {/* TAB: DATABASE */}
        {/* ================================================================== */}
        <TabsContent value="database" className="space-y-8">
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-3">
              <Database className="w-6 h-6 text-primary" />
              Database Schema
            </h2>
            <p className="text-muted-foreground">
              PostgreSQL 17 with pgvector extension for vector similarity search.
            </p>
          </div>

          {/* ERD */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle>Entity Relationship Diagram</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="rounded-xl bg-zinc-900 border border-zinc-800 p-6 overflow-x-auto">
                <div className="min-w-[700px] flex justify-around items-start gap-6">
                  {/* Users Table */}
                  <div className="rounded-lg border-2 border-cyan-500/50 overflow-hidden">
                    <div className="bg-cyan-500/20 px-4 py-2 border-b border-cyan-500/50">
                      <p className="font-bold text-cyan-400">users</p>
                    </div>
                    <div className="p-4 space-y-2">
                      <div className="flex items-center gap-2">
                        <Key className="w-3 h-3 text-yellow-400" />
                        <span className="text-sm text-zinc-300">id</span>
                        <Badge className="text-[10px]">PK</Badge>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">email</span>
                        <Badge variant="outline" className="text-[10px]">unique</Badge>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">password_digest</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex flex-col items-center justify-center pt-12">
                    <span className="text-xs text-zinc-500">1:N</span>
                    <ArrowRight className="w-8 h-8 text-zinc-500" />
                  </div>

                  {/* Knowledge Bases Table */}
                  <div className="rounded-lg border-2 border-purple-500/50 overflow-hidden">
                    <div className="bg-purple-500/20 px-4 py-2 border-b border-purple-500/50">
                      <p className="font-bold text-purple-400">knowledge_bases</p>
                    </div>
                    <div className="p-4 space-y-2">
                      <div className="flex items-center gap-2">
                        <Key className="w-3 h-3 text-yellow-400" />
                        <span className="text-sm text-zinc-300">id</span>
                        <Badge className="text-[10px]">PK</Badge>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">user_id</span>
                        <Badge variant="outline" className="text-[10px]">FK</Badge>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">name</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">description</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex flex-col items-center justify-center pt-12">
                    <span className="text-xs text-zinc-500">1:N</span>
                    <ArrowRight className="w-8 h-8 text-zinc-500" />
                  </div>

                  {/* Documents Table */}
                  <div className="rounded-lg border-2 border-green-500/50 overflow-hidden">
                    <div className="bg-green-500/20 px-4 py-2 border-b border-green-500/50">
                      <p className="font-bold text-green-400">documents</p>
                    </div>
                    <div className="p-4 space-y-2">
                      <div className="flex items-center gap-2">
                        <Key className="w-3 h-3 text-yellow-400" />
                        <span className="text-sm text-zinc-300">id</span>
                        <Badge className="text-[10px]">PK</Badge>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">knowledge_base_id</span>
                        <Badge variant="outline" className="text-[10px]">FK</Badge>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">title</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">content</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">status</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex flex-col items-center justify-center pt-12">
                    <span className="text-xs text-zinc-500">1:N</span>
                    <ArrowRight className="w-8 h-8 text-zinc-500" />
                  </div>

                  {/* Chunks Table */}
                  <div className="rounded-lg border-2 border-pink-500/50 overflow-hidden">
                    <div className="bg-pink-500/20 px-4 py-2 border-b border-pink-500/50">
                      <p className="font-bold text-pink-400">chunks</p>
                    </div>
                    <div className="p-4 space-y-2">
                      <div className="flex items-center gap-2">
                        <Key className="w-3 h-3 text-yellow-400" />
                        <span className="text-sm text-zinc-300">id</span>
                        <Badge className="text-[10px]">PK</Badge>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">document_id</span>
                        <Badge variant="outline" className="text-[10px]">FK</Badge>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">content</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="w-3" />
                        <span className="text-sm text-zinc-300">chunk_index</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <Cpu className="w-3 h-3 text-cyan-400" />
                        <span className="text-sm text-cyan-300">embedding</span>
                        <Badge className="text-[10px] bg-cyan-500/20 text-cyan-400">vector[768]</Badge>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Schema */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle>Complete Schema</CardTitle>
            </CardHeader>
            <CardContent>
              <CodeBlock
                filename="db/schema.rb"
                language="ruby"
                code={`ActiveRecord::Schema[8.0].define(version: 2024_01_01_000004) do
  enable_extension "vector"

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "knowledge_bases", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], unique: true
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "knowledge_base_id", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"]
  end

  create_table "chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.text "content", null: false
    t.integer "chunk_index", null: false
    t.vector "embedding", limit: 768  # pgvector type
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "chunk_index"], unique: true
    t.index ["embedding"], using: :hnsw, opclass: :vector_cosine_ops
  end

  add_foreign_key "knowledge_bases", "users"
  add_foreign_key "documents", "knowledge_bases"
  add_foreign_key "chunks", "documents"
end`}
              />
            </CardContent>
          </Card>
        </TabsContent>

        {/* ================================================================== */}
        {/* TAB: API */}
        {/* ================================================================== */}
        <TabsContent value="api" className="space-y-8">
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-3">
              <Code className="w-6 h-6 text-primary" />
              API Reference
            </h2>
            <p className="text-muted-foreground">
              Complete REST API documentation with examples.
            </p>
          </div>

          <Card className="glass-card">
            <CardHeader>
              <CardTitle>API Endpoints</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border/50 text-left">
                      <th className="py-3 px-4 font-medium">Method</th>
                      <th className="py-3 px-4 font-medium">Endpoint</th>
                      <th className="py-3 px-4 font-medium">Description</th>
                      <th className="py-3 px-4 font-medium">Auth</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border/30">
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-green-500/20 text-green-400">GET</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/health</td>
                      <td className="py-3 px-4 text-muted-foreground">Health check</td>
                      <td className="py-3 px-4"><Badge variant="outline">No</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-yellow-500/20 text-yellow-400">POST</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/auth/register</td>
                      <td className="py-3 px-4 text-muted-foreground">Create user account</td>
                      <td className="py-3 px-4"><Badge variant="outline">No</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-yellow-500/20 text-yellow-400">POST</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/auth/login</td>
                      <td className="py-3 px-4 text-muted-foreground">Login, get JWT token</td>
                      <td className="py-3 px-4"><Badge variant="outline">No</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-green-500/20 text-green-400">GET</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/auth/me</td>
                      <td className="py-3 px-4 text-muted-foreground">Get current user</td>
                      <td className="py-3 px-4"><Badge className="bg-primary/20 text-primary">Yes</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-green-500/20 text-green-400">GET</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/knowledge_bases</td>
                      <td className="py-3 px-4 text-muted-foreground">List all knowledge bases</td>
                      <td className="py-3 px-4"><Badge className="bg-primary/20 text-primary">Yes</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-yellow-500/20 text-yellow-400">POST</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/knowledge_bases</td>
                      <td className="py-3 px-4 text-muted-foreground">Create knowledge base</td>
                      <td className="py-3 px-4"><Badge className="bg-primary/20 text-primary">Yes</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-green-500/20 text-green-400">GET</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/knowledge_bases/:id/documents</td>
                      <td className="py-3 px-4 text-muted-foreground">List documents</td>
                      <td className="py-3 px-4"><Badge className="bg-primary/20 text-primary">Yes</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-yellow-500/20 text-yellow-400">POST</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/knowledge_bases/:id/documents</td>
                      <td className="py-3 px-4 text-muted-foreground">Create document</td>
                      <td className="py-3 px-4"><Badge className="bg-primary/20 text-primary">Yes</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-green-500/20 text-green-400">GET</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/knowledge_bases/:id/search</td>
                      <td className="py-3 px-4 text-muted-foreground">Semantic search</td>
                      <td className="py-3 px-4"><Badge className="bg-primary/20 text-primary">Yes</Badge></td>
                    </tr>
                    <tr>
                      <td className="py-3 px-4"><Badge className="bg-yellow-500/20 text-yellow-400">POST</Badge></td>
                      <td className="py-3 px-4 font-mono text-xs">/api/v1/knowledge_bases/:id/ask</td>
                      <td className="py-3 px-4 text-muted-foreground">Ask AI (RAG)</td>
                      <td className="py-3 px-4"><Badge className="bg-primary/20 text-primary">Yes</Badge></td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>

          {/* Example Requests */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle>Example Requests</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <CollapsibleSection title="Login Request" icon={Lock} defaultOpen>
                <div className="space-y-4">
                  <CodeBlock
                    language="bash"
                    showLineNumbers={false}
                    code={`curl -X POST http://localhost:3000/api/v1/auth/login \\
  -H "Content-Type: application/json" \\
  -d '{"email": "user@example.com", "password": "password123"}'`}
                  />
                  <CodeBlock
                    language="json"
                    filename="Response (200 OK)"
                    showLineNumbers={false}
                    code={`{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": { "id": 1, "email": "user@example.com" }
  }
}`}
                  />
                </div>
              </CollapsibleSection>

              <CollapsibleSection title="Search Request" icon={Search}>
                <div className="space-y-4">
                  <CodeBlock
                    language="bash"
                    showLineNumbers={false}
                    code={`curl -X GET "http://localhost:3000/api/v1/knowledge_bases/1/search?query=refund+policy&limit=5" \\
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..."`}
                  />
                  <CodeBlock
                    language="json"
                    filename="Response (200 OK)"
                    showLineNumbers={false}
                    code={`{
  "data": {
    "results": [
      { "content": "Refunds are processed within 30 days...", "similarity": 0.89 },
      { "content": "Our return policy allows...", "similarity": 0.76 }
    ],
    "query": "refund policy"
  }
}`}
                  />
                </div>
              </CollapsibleSection>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ================================================================== */}
        {/* TAB: SECURITY */}
        {/* ================================================================== */}
        <TabsContent value="security" className="space-y-8">
          <div>
            <h2 className="text-2xl font-bold mb-4 flex items-center gap-3">
              <Shield className="w-6 h-6 text-primary" />
              Security Implementation
            </h2>
            <p className="text-muted-foreground">
              Authentication, rate limiting, and security best practices.
            </p>
          </div>

          {/* Security Features */}
          <div className="grid md:grid-cols-2 gap-4">
            <Card className="glass-card">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Key className="w-5 h-5 text-yellow-400" />
                  JWT Authentication
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Algorithm</span>
                  <Badge>HS256</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Expiration</span>
                  <Badge>24 hours</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Secret Source</span>
                  <Badge variant="outline">ENV var</Badge>
                </div>
              </CardContent>
            </Card>

            <Card className="glass-card">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Fingerprint className="w-5 h-5 text-green-400" />
                  Password Security
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Hashing</span>
                  <Badge>bcrypt</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Min Length</span>
                  <Badge>6 chars</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Cost Factor</span>
                  <Badge variant="outline">12</Badge>
                </div>
              </CardContent>
            </Card>

            <Card className="glass-card">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Timer className="w-5 h-5 text-red-400" />
                  Rate Limiting
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">General</span>
                  <Badge>300/5min</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Login</span>
                  <Badge>5/20sec</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Register</span>
                  <Badge variant="outline">3/min</Badge>
                </div>
              </CardContent>
            </Card>

            <Card className="glass-card">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-base">
                  <Globe className="w-5 h-5 text-blue-400" />
                  CORS & Headers
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">CORS</span>
                  <Badge className="bg-green-500/20 text-green-400">Configured</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">XSS Protection</span>
                  <Badge className="bg-green-500/20 text-green-400">Enabled</Badge>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">Content-Type</span>
                  <Badge className="bg-green-500/20 text-green-400">nosniff</Badge>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Rack Attack Config */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle>Rack::Attack Configuration</CardTitle>
            </CardHeader>
            <CardContent>
              <CodeBlock
                filename="config/initializers/rack_attack.rb"
                language="ruby"
                code={`class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # General rate limit
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  # Strict login limit
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Registration limit
  throttle("registrations/ip", limit: 3, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/register" && req.post?
  end

  # Block requests without user agent
  blocklist("block bad IPs") do |req|
    req.user_agent.blank? && !req.path.start_with?("/api/v1/health")
  end

  # Custom throttled response
  self.throttled_responder = lambda do |req|
    [429, { "Content-Type" => "application/json" },
     [{ error: "Rate limit exceeded" }.to_json]]
  end
end`}
              />
            </CardContent>
          </Card>

          {/* Security Checklist */}
          <Card className="glass-card">
            <CardHeader>
              <CardTitle>Security Checklist</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {[
                  'Input validation with ActiveRecord validations',
                  'SQL injection prevention via ORM',
                  'User authorization on all protected routes',
                  'Secure password hashing with bcrypt',
                  'JWT tokens with expiration',
                  'Rate limiting on all endpoints',
                  'Environment variables for secrets',
                  'CORS configuration for frontend origin',
                ].map((item, i) => (
                  <div key={i} className="flex items-center gap-3 p-3 rounded-lg bg-green-500/10 border border-green-500/20">
                    <CheckCircle className="w-5 h-5 text-green-500" />
                    <span className="text-sm text-zinc-300">{item}</span>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Footer */}
      <Separator className="my-8" />
      <div className="text-center space-y-4">
        <p className="text-sm text-muted-foreground max-w-2xl mx-auto">
          All code snippets are extracted from actual source files.
          This documentation reflects the real implementation.
        </p>
        <div className="flex items-center justify-center gap-4">
          <Badge variant="outline" className="text-xs">
            <User className="w-3 h-3 mr-1" />
            Sathwik Sangeetham
          </Badge>
          <Badge variant="outline" className="text-xs">
            <Calendar className="w-3 h-3 mr-1" />
            February 2026
          </Badge>
        </div>
        <Link href="/auth/login">
          <Button className="btn-premium bg-primary hover:bg-primary/90 mt-4">
            <LogIn className="w-4 h-4 mr-2" />
            Get Started
          </Button>
        </Link>
      </div>
    </div>
  );
}
