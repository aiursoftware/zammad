# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

namespace :zammad do
  namespace :wcl do
    desc 'Sets up (or completes) the WCL HR app integration in Zammad; safe to run again'
    task setup: :environment do
      HrPortal::Setup.run
      puts 'WCL HR app integration is set up.'
    end
  end
end
