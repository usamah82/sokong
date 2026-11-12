<script setup lang="ts">
import type { FamilyMember } from './MemberFields.vue'

const place = defineModel<string>('place', { required: true })
const familyPhone = defineModel<string>('familyPhone', { required: true })
const head = defineModel<FamilyMember>('head', { required: true })
const latitude = defineModel<number | null>('latitude', { required: true })
const longitude = defineModel<number | null>('longitude', { required: true })

defineProps<{
  suggestion: null | { kind: 'suggested', name: string } | { kind: 'renamed' } | { kind: 'read' }
}>()

const emit = defineEmits<{ back: [], next: [], locate: [] }>()
const { t } = useI18n()

const ready = computed(() => place.value.trim() !== '' && head.value.name.trim() !== '')
</script>

<template>
  <form novalidate @submit.prevent="ready && emit('next')">
    <h1>{{ t('wizard.family.title') }}</h1>
    <label class="field">{{ t('wizard.family.place') }}
      <input
        id="place"
        v-model="place"
        type="text"
        :data-latitude="latitude ?? undefined"
        :data-longitude="longitude ?? undefined"
      >
    </label>
    <button id="use-location" class="secondary block" type="button" @click="emit('locate')">{{ t('wizard.family.locate') }}</button>
    <p v-if="suggestion?.kind === 'suggested'" class="hint">{{ t('wizard.family.suggested') }}</p>
    <p v-if="suggestion?.kind === 'suggested' || suggestion?.kind === 'renamed'" class="hint">{{ t('wizard.family.elsewhere') }}</p>
    <p v-if="suggestion?.kind === 'read'" class="hint">{{ t('wizard.family.read') }}</p>
    <label class="field">{{ t('wizard.family.familyPhone') }}
      <input id="family-phone" v-model="familyPhone" type="tel" autocomplete="tel">
    </label>
    <h2 class="label">{{ t('wizard.family.head') }}</h2>
    <MemberFields v-model:person="head" />
    <div class="actions">
      <button class="secondary" type="button" @click="emit('back')">{{ t('wizard.back') }}</button>
      <button class="primary" type="button" :disabled="!ready" @click="ready && emit('next')">{{ t('wizard.next') }}</button>
    </div>
  </form>
</template>
