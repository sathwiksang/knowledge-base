'use client';

import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Database,
  Server,
  Shield,
  Zap,
  Brain,
  Code,
  Layers,
  Lock,
  CheckCircle,
  GitBranch,
  Cpu,
  HardDrive,
  Network,
  FileCode,
  TestTube,
  Gauge,
  Eye,
  Settings,
  Boxes,
  CircuitBoard,
  Workflow,
  BarChart,
  LogIn,
} from 'lucide-react';

const projectPhases = [
  {
    phase: 1,
    title: 'Project Setup & Core Models',
    description: 'Foundation setup with Rails 8.1.2, PostgreSQL 17, and pgvector extension for vector similarity search.',
    technologies: ['Ruby 3.4.8', 'Rails 8.1.2', 'PostgreSQL 17', 'pgvector', 'RSpec'],
    highlights: [
      'Rails API-only mode configuration',
      'PostgreSQL with pgvector extension',
      'Core models: User, KnowledgeBase, Document, Chunk',
      'Database migrations with vector columns',
    ],
    icon: Database,
  },
  {
    phase: 2,
    title: 'JWT Authentication System',
    description: 'Secure authentication using JSON Web Tokens with bcrypt password hashing.',
    technologies: ['JWT', 'bcrypt', 'SecureRandom'],
    highlights: [
      'User registration with email validation',
      'Secure password hashing with bcrypt',
      'JWT token generation and validation',
      'Token expiration handling',
    ],
    icon: Lock,
  },
  {
    phase: 3,
    title: 'RESTful API Design',
    description: 'Complete CRUD operations with JSON:API conventions and proper HTTP status codes.',
    technologies: ['REST', 'JSON:API', 'Blueprinter'],
    highlights: [
      'Knowledge Base CRUD endpoints',
      'Document management API',
      'Nested routing for documents',
      'Blueprinter serializers',
    ],
    icon: Network,
  },
  {
    phase: 4,
    title: 'Document Processing Pipeline',
    description: 'Automated document chunking and processing for optimal search performance.',
    technologies: ['Text Processing', 'Chunking Algorithm'],
    highlights: [
      'Intelligent text chunking',
      'Configurable chunk size and overlap',
      'Metadata preservation',
      'Processing status tracking',
    ],
    icon: FileCode,
  },
  {
    phase: 5,
    title: 'Vector Embeddings with Ollama',
    description: 'Local AI-powered embeddings using nomic-embed-text model for semantic understanding.',
    technologies: ['Ollama', 'nomic-embed-text', '768-dim vectors'],
    highlights: [
      'Local embedding generation',
      '768-dimensional vector representations',
      'Semantic text understanding',
      'Privacy-preserving AI processing',
    ],
    icon: Brain,
  },
  {
    phase: 6,
    title: 'Background Job Processing',
    description: 'Asynchronous document processing using Solid Queue for seamless user experience.',
    technologies: ['Solid Queue', 'ActiveJob', 'Background Workers'],
    highlights: [
      'Solid Queue integration',
      'Async document indexing',
      'Job status monitoring',
      'Error handling and retries',
    ],
    icon: Workflow,
  },
  {
    phase: 7,
    title: 'Vector Similarity Search',
    description: 'High-performance semantic search using pgvector cosine similarity.',
    technologies: ['pgvector', 'Cosine Similarity', 'Vector Index'],
    highlights: [
      'Semantic search endpoints',
      'Cosine similarity ranking',
      'Configurable result limits',
      'Search performance optimization',
    ],
    icon: Gauge,
  },
  {
    phase: 8,
    title: 'RAG Question Answering',
    description: 'Retrieval-Augmented Generation using llama3.2:3b for accurate, sourced answers.',
    technologies: ['RAG', 'llama3.2:3b', 'LLM Integration'],
    highlights: [
      'Context-aware Q&A system',
      'Source citation tracking',
      'Customizable chunk retrieval',
      'Response quality optimization',
    ],
    icon: CircuitBoard,
  },
  {
    phase: 9,
    title: 'Error Handling & API Standards',
    description: 'Comprehensive error handling with consistent JSON error responses.',
    technologies: ['Exception Handling', 'HTTP Status Codes', 'Error Serialization'],
    highlights: [
      'Custom error classes',
      'Consistent error format',
      'Request ID tracking',
      'Validation error handling',
    ],
    icon: Shield,
  },
  {
    phase: 10,
    title: 'API Documentation',
    description: 'Interactive API documentation using Swagger/OpenAPI specification.',
    technologies: ['Swagger', 'OpenAPI 3.0', 'Rswag'],
    highlights: [
      'Auto-generated API docs',
      'Interactive testing interface',
      'Request/response examples',
      'Schema documentation',
    ],
    icon: Code,
  },
  {
    phase: 11,
    title: 'Comprehensive Testing',
    description: 'Extensive test coverage with RSpec, including edge cases and performance tests.',
    technologies: ['RSpec', 'FactoryBot', 'SimpleCov', 'rspec-benchmark'],
    highlights: [
      '609+ passing tests',
      '87%+ code coverage',
      'Edge case validation',
      'Performance benchmarking',
    ],
    icon: TestTube,
  },
  {
    phase: 12,
    title: 'Security & Performance Audit',
    description: 'Security scanning with Brakeman, code linting with RuboCop, and performance optimization.',
    technologies: ['Brakeman', 'RuboCop', 'Performance Tuning'],
    highlights: [
      '0 security vulnerabilities',
      '0 code style violations',
      'Query optimization',
      'Production-ready codebase',
    ],
    icon: Eye,
  },
];

const techStackCategories = [
  {
    category: 'Backend Framework',
    items: [
      { name: 'Ruby', version: '3.4.8', description: 'Dynamic, object-oriented programming language' },
      { name: 'Ruby on Rails', version: '8.1.2', description: 'Full-stack web application framework' },
      { name: 'Rack', version: '3.x', description: 'Modular Ruby webserver interface' },
    ],
    icon: Server,
  },
  {
    category: 'Database & Storage',
    items: [
      { name: 'PostgreSQL', version: '17', description: 'Advanced open-source relational database' },
      { name: 'pgvector', version: '0.8+', description: 'Vector similarity search extension' },
      { name: 'Solid Cache', version: '1.x', description: 'Database-backed Rails cache store' },
    ],
    icon: HardDrive,
  },
  {
    category: 'AI & Machine Learning',
    items: [
      { name: 'Ollama', version: 'Latest', description: 'Local large language model runner' },
      { name: 'nomic-embed-text', version: '1.5', description: '768-dim embedding model' },
      { name: 'llama3.2:3b', version: '3b', description: 'Language model for Q&A generation' },
    ],
    icon: Brain,
  },
  {
    category: 'Background Processing',
    items: [
      { name: 'Solid Queue', version: '1.x', description: 'Database-backed Active Job backend' },
      { name: 'ActiveJob', version: '8.x', description: 'Rails job framework' },
    ],
    icon: Workflow,
  },
  {
    category: 'Authentication & Security',
    items: [
      { name: 'JWT', version: '2.x', description: 'JSON Web Token authentication' },
      { name: 'bcrypt', version: '3.x', description: 'Secure password hashing' },
      { name: 'Brakeman', version: 'Latest', description: 'Security vulnerability scanner' },
    ],
    icon: Lock,
  },
  {
    category: 'Testing & Quality',
    items: [
      { name: 'RSpec', version: '3.x', description: 'BDD testing framework' },
      { name: 'FactoryBot', version: '6.x', description: 'Test data factories' },
      { name: 'SimpleCov', version: '0.22', description: 'Code coverage analysis' },
      { name: 'RuboCop', version: 'Latest', description: 'Ruby code linter' },
    ],
    icon: TestTube,
  },
  {
    category: 'Frontend Stack',
    items: [
      { name: 'Next.js', version: '16', description: 'React framework with App Router' },
      { name: 'TypeScript', version: '5.x', description: 'Typed JavaScript superset' },
      { name: 'Tailwind CSS', version: '4.x', description: 'Utility-first CSS framework' },
      { name: 'shadcn/ui', version: 'Latest', description: 'Accessible component library' },
    ],
    icon: Layers,
  },
  {
    category: 'State & API',
    items: [
      { name: 'Zustand', version: '5.x', description: 'Lightweight state management' },
      { name: 'Axios', version: '1.x', description: 'HTTP client for API calls' },
      { name: 'React Hook Form', version: '7.x', description: 'Form validation library' },
    ],
    icon: Boxes,
  },
];

const projectStats = [
  { label: 'Test Cases', value: '609+', icon: TestTube },
  { label: 'Code Coverage', value: '87%+', icon: BarChart },
  { label: 'Security Issues', value: '0', icon: Shield },
  { label: 'Lint Violations', value: '0', icon: CheckCircle },
];

export default function PublicAboutPage() {
  return (
    <div className="space-y-8 animate-fade-in max-w-6xl mx-auto">
      {/* Header */}
      <div className="text-center">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-primary/10 border border-primary/20 mb-4">
          <Cpu className="w-8 h-8 text-primary" />
        </div>
        <h1 className="text-2xl sm:text-3xl font-bold mb-2">About This Project</h1>
        <p className="text-sm sm:text-base text-muted-foreground max-w-3xl mx-auto">
          A production-ready, AI-powered knowledge management system built with Ruby on Rails
          and modern web technologies. This project demonstrates enterprise-grade software
          engineering practices across 12 development phases.
        </p>
      </div>

      {/* CTA to Sign In */}
      <Card className="glass-card border-primary/30">
        <CardContent className="p-4 sm:p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h3 className="font-semibold mb-1">Ready to experience it?</h3>
            <p className="text-sm text-muted-foreground">
              Create an account to start using the Knowledge Base platform
            </p>
          </div>
          <Link href="/auth/login" className="flex-shrink-0">
            <Button className="btn-premium bg-primary hover:bg-primary/90 w-full sm:w-auto">
              <LogIn className="w-4 h-4 mr-2" />
              Sign In
            </Button>
          </Link>
        </CardContent>
      </Card>

      {/* Project Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {projectStats.map((stat) => (
          <Card key={stat.label} className="glass-card border-border/50">
            <CardContent className="p-4 text-center">
              <stat.icon className="w-6 h-6 text-primary mx-auto mb-2" />
              <p className="text-2xl font-bold">{stat.value}</p>
              <p className="text-xs text-muted-foreground">{stat.label}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Architecture Overview */}
      <Card className="glass-card border-border/50">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <GitBranch className="w-5 h-5 text-primary" />
            Architecture Overview
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid md:grid-cols-3 gap-6">
            <div className="space-y-3">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-emerald-500"></div>
                <span className="font-medium">Frontend Layer</span>
              </div>
              <p className="text-sm text-muted-foreground pl-5">
                Next.js with TypeScript provides a modern, type-safe React application
                with server-side rendering capabilities and the App Router for optimal performance.
              </p>
            </div>
            <div className="space-y-3">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-blue-500"></div>
                <span className="font-medium">API Layer</span>
              </div>
              <p className="text-sm text-muted-foreground pl-5">
                Rails 8.1.2 API serves RESTful endpoints with JWT authentication,
                request validation, and comprehensive error handling.
              </p>
            </div>
            <div className="space-y-3">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-violet-500"></div>
                <span className="font-medium">AI Layer</span>
              </div>
              <p className="text-sm text-muted-foreground pl-5">
                Ollama provides local AI processing for embeddings and LLM responses,
                ensuring data privacy while enabling semantic search and RAG capabilities.
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Development Phases */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold flex items-center gap-2">
          <Layers className="w-5 h-5 text-primary" />
          Development Phases
        </h2>
        <p className="text-muted-foreground">
          This project was built through 12 comprehensive development phases, each adding
          essential functionality while maintaining code quality and test coverage.
        </p>
        <ScrollArea className="h-[500px] pr-4">
          <div className="grid gap-4">
            {projectPhases.map((phase, index) => (
              <Card
                key={phase.phase}
                className="glass-card border-border/50 stagger-item"
                style={{ animationDelay: `${index * 0.05}s` }}
              >
                <CardContent className="p-5">
                  <div className="flex gap-4">
                    <div className="flex-shrink-0">
                      <div className="w-12 h-12 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-center">
                        <phase.icon className="w-6 h-6 text-primary" />
                      </div>
                      <div className="flex justify-center mt-2">
                        <Badge variant="outline" className="text-primary border-primary/30 text-xs">
                          Phase {phase.phase}
                        </Badge>
                      </div>
                    </div>
                    <div className="flex-1 min-w-0">
                      <h3 className="font-semibold mb-1">{phase.title}</h3>
                      <p className="text-sm text-muted-foreground mb-3">
                        {phase.description}
                      </p>
                      <div className="flex flex-wrap gap-1.5 mb-3">
                        {phase.technologies.map((tech) => (
                          <Badge
                            key={tech}
                            variant="secondary"
                            className="text-xs bg-muted/50"
                          >
                            {tech}
                          </Badge>
                        ))}
                      </div>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-1.5">
                        {phase.highlights.map((highlight, i) => (
                          <div key={i} className="flex items-center gap-1.5">
                            <CheckCircle className="w-3 h-3 text-emerald-500 flex-shrink-0" />
                            <span className="text-xs text-muted-foreground">
                              {highlight}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </ScrollArea>
      </div>

      <Separator className="my-8" />

      {/* Complete Tech Stack */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold flex items-center gap-2">
          <Settings className="w-5 h-5 text-primary" />
          Complete Technology Stack
        </h2>
        <p className="text-muted-foreground">
          A comprehensive overview of all technologies, frameworks, and libraries used in this project.
        </p>
        <div className="grid md:grid-cols-2 gap-4">
          {techStackCategories.map((category) => (
            <Card key={category.category} className="glass-card border-border/50">
              <CardHeader className="pb-3">
                <CardTitle className="text-base flex items-center gap-2">
                  <category.icon className="w-4 h-4 text-primary" />
                  {category.category}
                </CardTitle>
              </CardHeader>
              <CardContent className="pt-0">
                <div className="space-y-3">
                  {category.items.map((item) => (
                    <div
                      key={item.name}
                      className="flex items-start justify-between gap-2 py-2 border-b border-border/30 last:border-0"
                    >
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-sm">{item.name}</span>
                          <Badge variant="outline" className="text-xs">
                            {item.version}
                          </Badge>
                        </div>
                        <p className="text-xs text-muted-foreground truncate">
                          {item.description}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      {/* Key Features */}
      <Card className="glass-card border-border/50 border-primary/20">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Zap className="w-5 h-5 text-primary" />
            Key Differentiators
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid md:grid-cols-2 gap-4">
            <div className="space-y-3">
              <div className="flex items-start gap-3">
                <Shield className="w-5 h-5 text-emerald-500 mt-0.5" />
                <div>
                  <p className="font-medium text-sm">Privacy-First Design</p>
                  <p className="text-xs text-muted-foreground">
                    All AI processing happens locally via Ollama. Your data never leaves your infrastructure.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <Brain className="w-5 h-5 text-blue-500 mt-0.5" />
                <div>
                  <p className="font-medium text-sm">Semantic Understanding</p>
                  <p className="text-xs text-muted-foreground">
                    768-dimensional vector embeddings enable meaning-based search, not just keyword matching.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <Gauge className="w-5 h-5 text-amber-500 mt-0.5" />
                <div>
                  <p className="font-medium text-sm">Production Ready</p>
                  <p className="text-xs text-muted-foreground">
                    Built with enterprise patterns: background jobs, error handling, comprehensive testing.
                  </p>
                </div>
              </div>
            </div>
            <div className="space-y-3">
              <div className="flex items-start gap-3">
                <Layers className="w-5 h-5 text-violet-500 mt-0.5" />
                <div>
                  <p className="font-medium text-sm">Modern Architecture</p>
                  <p className="text-xs text-muted-foreground">
                    Clean separation of concerns with Rails API backend and Next.js frontend.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <TestTube className="w-5 h-5 text-pink-500 mt-0.5" />
                <div>
                  <p className="font-medium text-sm">Thoroughly Tested</p>
                  <p className="text-xs text-muted-foreground">
                    609+ tests covering unit, integration, and edge cases with 87%+ coverage.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <Code className="w-5 h-5 text-cyan-500 mt-0.5" />
                <div>
                  <p className="font-medium text-sm">Clean Codebase</p>
                  <p className="text-xs text-muted-foreground">
                    Zero RuboCop violations and zero Brakeman security warnings.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
