<script setup lang="ts">
const stage = ref(1)
const mode = ref<'self' | 'behalf'>('self')
const phone = ref('')
const email = ref('')
const { t } = useI18n()
</script>

<template>
  <main class="phone">
    <p class="mark">{{ t('wizard.mark') }}</p>
    <p class="step">{{ t('wizard.step', { current: stage, total: 4 }) }}</p>
    <StageEnroler
      v-if="stage === 1"
      v-model:mode="mode"
      v-model:phone="phone"
      v-model:email="email"
      @next="stage = 2"
    />
    <section v-else>
      <h1>{{ t('wizard.family.title') }}</h1>
      <div class="actions">
        <button class="secondary" type="button" @click="stage = 1">{{ t('wizard.back') }}</button>
      </div>
    </section>
  </main>
</template>
