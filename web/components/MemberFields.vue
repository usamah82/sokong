<script lang="ts">
export type FamilyMember = {
  name: string
  age: string
  gender: 'male' | 'female' | 'unspecified'
  description: string
  education: boolean
  working: boolean
  job: string
  amount: string
}
</script>

<script setup lang="ts">
const person = defineModel<FamilyMember>('person', { required: true })
const props = defineProps<{ scope?: string }>()
const { t } = useI18n()

const genders = [
  [ 'male', 'wizard.family.male' ],
  [ 'female', 'wizard.family.female' ],
  [ 'unspecified', 'wizard.family.unspecified' ]
] as const

const genderName = computed(() => props.scope ? `${props.scope}-gender` : 'gender')

function inputId(name: string) {
  if (props.scope) return `${props.scope}-${name}`
  return name === 'name' ? 'head-name' : name
}
</script>

<template>
  <label class="field">{{ t('wizard.family.name') }}
    <input :id="inputId('name')" v-model="person.name" type="text" autocomplete="name">
  </label>
  <label class="field">{{ t('wizard.family.age') }}
    <input :id="inputId('age')" v-model="person.age" type="text" inputmode="numeric">
  </label>
  <fieldset>
    <legend>{{ t('wizard.family.gender') }}</legend>
    <label v-for="[value, label] in genders" :key="value" class="choice">
      <input v-model="person.gender" type="radio" :name="genderName" :value="value">
      <span>{{ t(label) }}</span>
    </label>
  </fieldset>
  <label class="field">{{ t('wizard.family.description') }}
    <textarea :id="inputId('description')" v-model="person.description" rows="3" />
  </label>
  <label class="check">
    <input :id="inputId('education')" v-model="person.education" type="checkbox">
    <span>{{ t('wizard.family.education') }}</span>
  </label>
  <label class="check">
    <input :id="inputId('working')" v-model="person.working" type="checkbox">
    <span>{{ t('wizard.family.working') }}</span>
  </label>
  <template v-if="person.working">
    <label class="field">{{ t('wizard.family.job') }}
      <input :id="inputId('job')" v-model="person.job" type="text">
    </label>
    <label class="field">{{ t('wizard.family.amount') }}
      <input :id="inputId('amount')" v-model="person.amount" type="text" inputmode="numeric">
    </label>
  </template>
</template>
