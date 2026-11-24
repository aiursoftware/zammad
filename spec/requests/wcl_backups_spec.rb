# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: Admin > System > Backups.
RSpec.describe 'WCL backups', performs_jobs: true, type: :request do
  let(:dir) { Dir.mktmpdir }

  before { stub_const('ENV', ENV.to_h.merge('BACKUP_DIR' => dir)) }
  after  { FileUtils.rm_rf(dir) }

  context 'when an admin' do
    before do
      File.write(File.join(dir, '20261101030000_zammad_db.psql.gz'), 'x')
      authenticated_as(create(:admin))
    end

    it 'lists the backups' do
      get '/api/v1/wcl/backups', as: :json

      expect(json_response['backups'].pluck('id')).to eq(['20261101030000'])
    end

    it 'starts a backup' do
      expect { post '/api/v1/wcl/backups', as: :json }.to have_enqueued_job(WclBackupJob)
    end

    it 'deletes a backup' do
      delete '/api/v1/wcl/backups/20261101030000', as: :json

      expect(json_response['backups']).to be_empty
    end
  end

  context 'when an agent' do
    before { authenticated_as(create(:agent)) }

    it 'is forbidden' do
      get '/api/v1/wcl/backups', as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
