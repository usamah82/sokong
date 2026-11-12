<script setup lang="ts">
const howToFind = defineModel<string>('howToFind', { required: true })
const otherHelp = defineModel<string>('otherHelp', { required: true })
const help = defineModel<string[]>('help', { required: true })

defineProps<{
  error: string
  submitting: boolean
}>()

const emit = defineEmits<{ back: [], submit: [] }>()
const { t } = useI18n()

const choices = [
  [ 'food', 'wizard.notes.food' ],
  [ 'clothing', 'wizard.notes.clothing' ],
  [ 'school_supplies', 'wizard.notes.schoolSupplies' ],
  [ 'help_applying', 'wizard.notes.helpApplying' ]
] as const
</script>

<template>
  <form novalidate @submit.prevent="emit('submit')">
    <h1>{{ t('wizard.notes.title') }}</h1>
    <label class="field">{{ t('wizard.notes.howToFind') }}
      <textarea id="how-to-find" v-model="howToFind" rows="3" />
    </label>
    <fieldset>
      <legend>{{ t('wizard.notes.help') }}</legend>
      <label v-for="[value, label] in choices" :key="value" class="check">
        <input v-model="help" type="checkbox" :value="value">
        <span>{{ t(label) }}</span>
      </label>
    </fieldset>
    <label class="field">{{ t('wizard.notes.other') }}
      <textarea id="other-help" v-model="otherHelp" rows="3" />
    </label>
    <p v-if="error" class="error" role="alert">{{ error }}</p>
    <div class="actions">
      <button class="secondary" type="button" @click="emit('back')">{{ t('wizard.back') }}</button>
      <button id="submit" class="primary" type="button" :disabled="submitting" @click="emit('submit')">{{ t('wizard.notes.submit') }}</button>
    </div>
  </form>
</template>
