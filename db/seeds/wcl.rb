# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the HR app integration on a fresh install (see HrPortal::Setup).
#
# The seeds before this one create records with fixed ids and only db/seeds.rb resets the id
# sequences, after all of them; reset them now so the records made here get fresh ids.
DbHelper.import_post
HrPortal::Setup.run
