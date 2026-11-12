<script setup lang="ts">
const props = defineProps<{ email: string }>()
const { t } = useI18n()
const shown = computed(() => props.email.trim())
</script>

<template>
  <div class="confirm">
    <h1>{{ t('wizard.confirmation.title') }}</h1>
    <p v-if="shown">{{ t('wizard.confirmation.signUp') }}</p>
    <p v-if="shown" class="email">{{ shown }}</p>
  </div>
</template>
