<script setup lang="ts">
import { computed, ref } from 'vue'
import type { FamilyMember } from './MemberFields.vue'

const people = defineModel<FamilyMember[]>('people', { required: true })

const emit = defineEmits<{ back: [], next: [] }>()
const { t } = useI18n()

let nextKey = 0
const keys = ref<number[]>(people.value.map(() => nextKey++))

const ready = computed(() => people.value.every((person) => person.name.trim() !== ''))

function blankPerson(): FamilyMember {
  return {
    name: '',
    age: '',
    gender: 'unspecified',
    description: '',
    education: false,
    working: false,
    job: '',
    amount: ''
  }
}

function addPerson() {
  people.value = [ ...people.value, blankPerson() ]
  keys.value = [ ...keys.value, nextKey++ ]
}

function removePerson(index: number) {
  people.value = people.value.filter((_, item) => item !== index)
  keys.value = keys.value.filter((_, item) => item !== index)
}
</script>

<template>
  <form novalidate @submit.prevent="ready && emit('next')">
    <h1>{{ t('wizard.members.title') }}</h1>
    <p v-if="people.length === 0" class="hint">{{ t('wizard.members.empty') }}</p>
    <section v-for="(person, index) in people" :key="keys[index]" class="person">
      <h2 class="label">{{ t('wizard.members.person') }}</h2>
      <MemberFields v-model:person="people[index]" :scope="`member-${index}`" />
      <button class="secondary block" type="button" @click="removePerson(index)">{{ t('wizard.members.remove') }}</button>
    </section>
    <button id="add-person" class="secondary block" type="button" @click="addPerson">{{ t('wizard.members.add') }}</button>
    <div class="actions">
      <button class="secondary" type="button" @click="emit('back')">{{ t('wizard.back') }}</button>
      <button class="primary" type="button" :disabled="!ready" @click="ready && emit('next')">{{ t('wizard.next') }}</button>
    </div>
  </form>
</template>
