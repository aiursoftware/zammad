# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

namespace :zammad do
  namespace :wcl do
    desc 'Sets up (or completes) the WCL customizations in Zammad; safe to run again'
    task setup: :environment do
      Wcl::Setup.run
      puts 'WCL customizations are set up.'
    end
  end
end
