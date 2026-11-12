<script setup lang="ts">
import type { FamilyMember } from './MemberFields.vue'

const place = defineModel<string>('place', { required: true })
const familyPhone = defineModel<string>('familyPhone', { required: true })
const head = defineModel<FamilyMember>('head', { required: true })

const emit = defineEmits<{ back: [], next: [] }>()
const { t } = useI18n()

const ready = computed(() => place.value.trim() !== '' && head.value.name.trim() !== '')
</script>

<template>
  <form novalidate @submit.prevent="ready && emit('next')">
    <h1>{{ t('wizard.family.title') }}</h1>
    <label class="field">{{ t('wizard.family.place') }}
      <input id="place" v-model="place" type="text">
    </label>
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
