'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from '@/components/ui/collapsible';
import {
  Database,
  FileText,
  Search,
  MessageSquare,
  ChevronDown,
  ChevronRight,
  BookOpen,
  Lightbulb,
  HelpCircle,
  Zap,
  Shield,
  CheckCircle,
  ArrowRight,
  Layers,
  Brain,
  Server,
  LogIn,
} from 'lucide-react';

const gettingStartedSteps = [
  {
    step: 1,
    title: 'Create a Knowledge Base',
    description: 'A knowledge base is a container for your documents. Think of it as a folder that groups related content together.',
    instructions: [
      'Navigate to "Knowledge Bases" from the sidebar',
      'Click the "New Knowledge Base" button',
      'Enter a descriptive name (e.g., "Product Documentation")',
      'Optionally add a description',
      'Click "Create" to save',
    ],
    icon: Database,
  },
  {
    step: 2,
    title: 'Add Documents',
    description: 'Documents contain the content you want to search and query. The system automatically processes and indexes them for AI-powered search.',
    instructions: [
      'Open your knowledge base by clicking on it',
      'Click "Add Document"',
      'Enter a title for your document',
      'Paste or type your content',
      'Click "Add Document" to save',
      'Wait for the document to be indexed (status will change to "Indexed")',
    ],
    icon: FileText,
  },
  {
    step: 3,
    title: 'Search Your Content',
    description: 'Use semantic search to find relevant information. Unlike keyword search, this understands the meaning of your query.',
    instructions: [
      'Go to "Search" from the sidebar',
      'Select a knowledge base from the dropdown',
      'Enter your search query in natural language',
      'Click "Search" to get results',
      'Results are ranked by relevance with similarity scores',
    ],
    icon: Search,
  },
  {
    step: 4,
    title: 'Ask AI Questions',
    description: 'Get AI-generated answers to your questions based on your documents. The AI uses RAG (Retrieval-Augmented Generation) to provide accurate, sourced responses.',
    instructions: [
      'Navigate to "Ask AI" from the sidebar',
      'Select a knowledge base',
      'Type your question in natural language',
      'Press Enter or click Send',
      'View the AI answer along with source citations',
    ],
    icon: MessageSquare,
  },
];

const faqs = [
  {
    category: 'General',
    questions: [
      {
        q: 'What is this Knowledge Base application?',
        a: 'This is an enterprise-grade knowledge management platform that allows you to store documents and query them using AI. It uses advanced technologies like vector embeddings and Large Language Models (LLMs) to provide semantic search and intelligent Q&A capabilities.',
      },
      {
        q: 'What makes this different from regular search?',
        a: 'Traditional search matches keywords. Our semantic search understands the meaning behind your query. For example, searching for "programming language created in Japan" will find documents about Ruby, even if they don\'t contain those exact words.',
      },
      {
        q: 'Is my data secure?',
        a: 'Yes. All data is stored locally in your PostgreSQL database. The AI processing happens locally using Ollama, meaning your data never leaves your infrastructure. Authentication is handled via secure JWT tokens.',
      },
    ],
  },
  {
    category: 'Documents',
    questions: [
      {
        q: 'What happens when I add a document?',
        a: 'When you add a document, it goes through several processing steps: 1) The content is split into smaller chunks, 2) Each chunk is converted into a vector embedding using AI, 3) The embeddings are stored in the database for fast similarity search. This process typically takes a few seconds.',
      },
      {
        q: 'What document formats are supported?',
        a: 'Currently, the application accepts plain text content. You can paste content from any source including PDFs, Word documents, or web pages. Future versions may support direct file uploads.',
      },
      {
        q: 'Why is my document stuck in "Processing"?',
        a: 'Document processing requires the Ollama service to generate embeddings. Ensure Ollama is running and the embedding model (nomic-embed-text) is available. Check the System Status on the dashboard.',
      },
    ],
  },
  {
    category: 'Search & AI',
    questions: [
      {
        q: 'How does the similarity score work?',
        a: 'The similarity score (0-100%) indicates how closely a result matches your query semantically. Scores above 70% are typically highly relevant. The score is calculated using cosine similarity between vector embeddings.',
      },
      {
        q: 'What is RAG?',
        a: 'RAG stands for Retrieval-Augmented Generation. When you ask a question, the system first retrieves relevant document chunks using vector search, then sends those chunks along with your question to the LLM to generate an accurate, contextual answer.',
      },
      {
        q: 'Why does the AI sometimes say it cannot answer?',
        a: 'The AI only answers based on information in your documents. If your question is about something not covered in the knowledge base, it will indicate that. This is by design to prevent hallucinations and ensure accuracy.',
      },
    ],
  },
  {
    category: 'Technical',
    questions: [
      {
        q: 'What AI models are used?',
        a: 'The application uses two AI models via Ollama: 1) nomic-embed-text for generating 768-dimensional vector embeddings, 2) llama3.2:3b for generating natural language answers. Both run locally for privacy.',
      },
      {
        q: 'What is vector search?',
        a: 'Vector search converts text into numerical representations (embeddings) that capture semantic meaning. Similar concepts have similar vectors. This enables finding relevant content even when exact keywords don\'t match.',
      },
      {
        q: 'How is the data stored?',
        a: 'Data is stored in PostgreSQL with the pgvector extension for efficient vector similarity search. Documents are split into chunks, each stored with its embedding vector for fast retrieval.',
      },
    ],
  },
];

const features = [
  {
    icon: Brain,
    title: 'Semantic Search',
    description: 'Find information based on meaning, not just keywords',
  },
  {
    icon: MessageSquare,
    title: 'AI-Powered Q&A',
    description: 'Ask questions in natural language and get sourced answers',
  },
  {
    icon: Layers,
    title: 'Document Chunking',
    description: 'Automatic splitting for optimal search performance',
  },
  {
    icon: Zap,
    title: 'Fast Processing',
    description: 'Background job processing for seamless experience',
  },
  {
    icon: Shield,
    title: 'Secure & Private',
    description: 'Local AI processing, JWT authentication, data isolation',
  },
  {
    icon: Server,
    title: 'Enterprise Ready',
    description: 'Built with production-grade technologies',
  },
];

export default function PublicHelpPage() {
  const [openFaq, setOpenFaq] = useState<string | null>(null);

  return (
    <div className="space-y-8 animate-fade-in max-w-5xl mx-auto">
      {/* Header */}
      <div className="text-center">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-primary/10 border border-primary/20 mb-4">
          <BookOpen className="w-8 h-8 text-primary" />
        </div>
        <h1 className="text-2xl sm:text-3xl font-bold mb-2">Help Center</h1>
        <p className="text-sm sm:text-base text-muted-foreground max-w-2xl mx-auto">
          Everything you need to know about using the Knowledge Base application.
          Learn how to store, search, and query your documents with AI.
        </p>
      </div>

      {/* CTA to Sign In */}
      <Card className="glass-card border-primary/30">
        <CardContent className="p-4 sm:p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h3 className="font-semibold mb-1">Ready to get started?</h3>
            <p className="text-sm text-muted-foreground">
              Create an account to start building your knowledge base
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

      {/* Quick Overview */}
      <Card className="glass-card border-border/50">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Lightbulb className="w-5 h-5 text-primary" />
            What is Knowledge Base?
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-muted-foreground leading-relaxed">
            Knowledge Base is an AI-powered document management and retrieval system.
            It allows you to upload documents, automatically index them using advanced
            vector embeddings, and then search or ask questions about your content
            using natural language.
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3 sm:gap-4 pt-4">
            {features.map((feature) => (
              <div
                key={feature.title}
                className="flex items-start gap-3 p-3 rounded-lg bg-muted/30"
              >
                <feature.icon className="w-5 h-5 text-primary mt-0.5" />
                <div>
                  <p className="font-medium text-sm">{feature.title}</p>
                  <p className="text-xs text-muted-foreground">
                    {feature.description}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Tabs for different sections */}
      <Tabs defaultValue="getting-started" className="space-y-6">
        <TabsList className="grid w-full grid-cols-2 glass-card">
          <TabsTrigger value="getting-started">Getting Started</TabsTrigger>
          <TabsTrigger value="faq">FAQ</TabsTrigger>
        </TabsList>

        {/* Getting Started Tab */}
        <TabsContent value="getting-started" className="space-y-6">
          <div className="grid gap-6">
            {gettingStartedSteps.map((step, index) => (
              <Card
                key={step.step}
                className="glass-card border-border/50 stagger-item"
                style={{ animationDelay: `${index * 0.1}s` }}
              >
                <CardContent className="p-4 sm:p-6">
                  <div className="flex flex-col sm:flex-row gap-4 sm:gap-6">
                    <div className="flex sm:flex-col items-center sm:items-center gap-3 sm:gap-0 flex-shrink-0">
                      <div className="w-10 h-10 sm:w-12 sm:h-12 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-center">
                        <step.icon className="w-5 h-5 sm:w-6 sm:h-6 text-primary" />
                      </div>
                      <Badge variant="outline" className="text-primary border-primary/30 sm:mt-2">
                        Step {step.step}
                      </Badge>
                    </div>
                    <div className="flex-1">
                      <h3 className="text-base sm:text-lg font-semibold mb-2">{step.title}</h3>
                      <p className="text-muted-foreground text-sm mb-4">{step.description}</p>
                      <div className="space-y-2">
                        {step.instructions.map((instruction, i) => (
                          <div key={i} className="flex items-start gap-2">
                            <CheckCircle className="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0" />
                            <span className="text-sm">{instruction}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>

          {/* Pro Tips */}
          <Card className="glass-card border-border/50 border-primary/30">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-primary">
                <Zap className="w-5 h-5" />
                Pro Tips
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="space-y-3">
                <li className="flex items-start gap-2">
                  <ArrowRight className="w-4 h-4 text-primary mt-1" />
                  <span className="text-sm">
                    <strong>Be specific with questions:</strong> Instead of "What is this about?",
                    ask "What are the main features of the authentication system?"
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <ArrowRight className="w-4 h-4 text-primary mt-1" />
                  <span className="text-sm">
                    <strong>Organize by topic:</strong> Create separate knowledge bases for
                    different subjects (e.g., "Technical Docs", "HR Policies", "Product Info")
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <ArrowRight className="w-4 h-4 text-primary mt-1" />
                  <span className="text-sm">
                    <strong>Add context:</strong> Include relevant titles and descriptions
                    for documents to improve search accuracy
                  </span>
                </li>
                <li className="flex items-start gap-2">
                  <ArrowRight className="w-4 h-4 text-primary mt-1" />
                  <span className="text-sm">
                    <strong>Check sources:</strong> Always review the source citations in
                    AI answers to verify the information
                  </span>
                </li>
              </ul>
            </CardContent>
          </Card>
        </TabsContent>

        {/* FAQ Tab */}
        <TabsContent value="faq" className="space-y-6">
          {faqs.map((category) => (
            <Card key={category.category} className="glass-card border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <HelpCircle className="w-5 h-5 text-primary" />
                  {category.category}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                {category.questions.map((faq, index) => (
                  <Collapsible
                    key={index}
                    open={openFaq === `${category.category}-${index}`}
                    onOpenChange={(open) =>
                      setOpenFaq(open ? `${category.category}-${index}` : null)
                    }
                  >
                    <CollapsibleTrigger className="flex items-center justify-between w-full p-4 rounded-lg hover:bg-muted/30 transition-colors text-left">
                      <span className="font-medium pr-4">{faq.q}</span>
                      {openFaq === `${category.category}-${index}` ? (
                        <ChevronDown className="w-4 h-4 text-muted-foreground flex-shrink-0" />
                      ) : (
                        <ChevronRight className="w-4 h-4 text-muted-foreground flex-shrink-0" />
                      )}
                    </CollapsibleTrigger>
                    <CollapsibleContent className="px-4 pb-4">
                      <p className="text-muted-foreground text-sm leading-relaxed pl-4 border-l-2 border-primary/30">
                        {faq.a}
                      </p>
                    </CollapsibleContent>
                  </Collapsible>
                ))}
              </CardContent>
            </Card>
          ))}
        </TabsContent>
      </Tabs>
    </div>
  );
}
