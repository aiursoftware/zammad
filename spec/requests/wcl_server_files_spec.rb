# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: Admin > System > Server Files.
RSpec.describe 'WCL server files', type: :request do
  let(:dir) { Dir.mktmpdir }

  before do
    stub_const('ENV', ENV.to_h.merge('BACKUP_DIR' => dir))
    File.write(File.join(dir, 'a.log'), 'hello')
  end

  after { FileUtils.rm_rf(dir) }

  context 'when an admin' do
    before { authenticated_as(create(:admin)) }

    it 'lists the files' do
      get '/api/v1/wcl/server_files', params: { root: 'backups' }, as: :json

      expect(json_response['entries'].pluck('name')).to eq(['a.log'])
    end

    it 'downloads a file' do
      get '/api/v1/wcl/server_files/download', params: { root: 'backups', path: 'a.log' }

      expect(response.body).to eq('hello')
    end

    it 'refuses paths outside the folder' do
      get '/api/v1/wcl/server_files/download', params: { root: 'backups', path: '../../../etc/passwd' }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'when an agent' do
    before { authenticated_as(create(:agent)) }

    it 'is forbidden' do
      get '/api/v1/wcl/server_files', params: { root: 'backups' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
