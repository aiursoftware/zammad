<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed } from 'vue'

import { useTicketCreateView } from '#shared/entities/ticket/composables/useTicketCreateView.ts'
import { useSessionStore } from '#shared/stores/session.ts'

import CommonInputSearch from '#mobile/components/CommonInputSearch/CommonInputSearch.vue'
import CommonSectionMenu from '#mobile/components/CommonSectionMenu/CommonSectionMenu.vue'
import type { MenuItem } from '#mobile/components/CommonSectionMenu/index.ts'
import { useTicketOverviews } from '#mobile/entities/ticket/composables/useTicketOverviews.ts'

const IS_DEV = import.meta.env.DEV

const session = useSessionStore()

// WCL customization: a full "New ticket" button instead of the small "+" in the corner, which sat
//   under the status bar on tall phones (e.g. Galaxy S23 Ultra) and was easy to miss.
const { ticketCreateEnabled } = useTicketCreateView()

const menu: MenuItem[] = [
  {
    type: 'link',
    link: '/tickets/view',
    label: __('Ticket overviews'),
    icon: { name: 'all-tickets', size: 'base' },
    iconBg: 'bg-pink',
    permission: ['ticket.agent', 'ticket.customer'],
  },
  // Cannot inline import.meta here, Vite fails
  ...(IS_DEV
    ? [
        {
          type: 'link' as const,
          link: '/playground',
          label: 'Playground',
          icon: { name: 'settings', size: 'small' as const },
          iconBg: 'bg-orange',
        },
      ]
    : []),
]

const overviews = useTicketOverviews()

const ticketOverview = computed<MenuItem[]>(() => {
  if (overviews.loading) return []

  return overviews.includedOverviews.map((overview) => {
    return {
      type: 'link',
      link: `/tickets/view/${overview.link}`,
      label: overview.name,
      information: overview.ticketCount,
    }
  })
})
</script>

<template>
  <div class="p-4 pt-[calc(1rem+env(safe-area-inset-top))]">
    <h1 class="mb-5 flex w-full items-center justify-center text-4xl font-bold">
      {{ $t('Home') }}
    </h1>
    <CommonLink :aria-label="$t('Search…')" link="/search">
      <CommonInputSearch aria-hidden="true" tabindex="-1" wrapper-class="mb-4" no-border />
    </CommonLink>
    <CommonLink
      v-if="ticketCreateEnabled"
      link="/tickets/create"
      :aria-label="$t('Create new ticket')"
      class="mb-4 flex w-full items-center justify-center gap-2 rounded-xl bg-blue px-4 py-3 text-base font-semibold text-white"
    >
      <CommonIcon name="add" size="small" decorative />
      {{ $t('New ticket') }}
    </CommonLink>
    <CommonSectionMenu :items="menu" />
    <CommonSectionMenu
      v-if="session.hasPermission(['ticket.agent', 'ticket.customer'])"
      :items="ticketOverview"
      :header-label="__('Ticket overview')"
      :action-label="__('Edit')"
      action-link="/favorite/ticket-overviews/edit"
    >
      <template v-if="overviews.loading" #before-items>
        <div class="flex w-full justify-center">
          <CommonIcon name="loading" animation="spin" />
        </div>
      </template>
    </CommonSectionMenu>
  </div>
</template>
