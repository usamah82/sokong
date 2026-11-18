<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  saved: Record<string, unknown> | null
  readonly: boolean
}>()

const { t } = useI18n()
const place = ref(text(props.saved?.place))
const rent = ref(props.saved?.rent_per_month == null ? '' : String(props.saved.rent_per_month))
const behind = ref(choice(props.saved?.behind_on_payments))
const water = ref(choice(props.saved?.has_water))
const electricity = ref(choice(props.saved?.has_electricity))
const rooms = ref(props.saved?.sleeping_rooms == null ? '' : String(props.saved.sleeping_rooms))
const safe = ref(choice(props.saved?.safe))
const unsafe = ref(text(props.saved?.unsafe_detail))
const meals = ref(text(props.saved?.meals))
const basket = ref(text(props.saved?.basket))
const notes = ref(text(props.saved?.notes))
const error = ref('')

function text(value: unknown) {
  return typeof value === 'string' ? value : ''
}

function choice(value: unknown) {
  if (value === true) return 'yes'
  if (value === false) return 'no'
  return ''
}

function yesNo(value: string) {
  if (value === '') return null
  return value === 'yes'
}

function whole(value: string, max: number) {
  const trimmed = value.trim()
  if (trimmed === '') return null
  if (!/^\d+$/.test(trimmed)) return false
  const parsed = Number(trimmed)
  if (parsed > max) return false
  return parsed
}

function attempt() {
  if (place.value === 'rent' && whole(rent.value, 999_999_999) === false) {
    error.value = t('interview.rentInvalid')
    return null
  }
  if (whole(rooms.value, 99) === false) {
    error.value = t('interview.roomsInvalid')
    return null
  }
  if (basket.value.trim().length > 500) {
    error.value = t('interview.basketTooLong')
    return null
  }
  if (notes.value.trim().length > 2000) {
    error.value = t('interview.notesTooLong')
    return null
  }
  error.value = ''
  return {
    place: place.value,
    rent_per_month: place.value === 'rent' ? whole(rent.value, 999_999_999) : null,
    behind_on_payments: place.value === 'rent' ? yesNo(behind.value) : null,
    has_water: yesNo(water.value),
    has_electricity: yesNo(electricity.value),
    sleeping_rooms: whole(rooms.value, 99),
    safe: yesNo(safe.value),
    unsafe_detail: safe.value === 'no' ? unsafe.value.trim() : '',
    meals: meals.value,
    basket: basket.value.trim(),
    notes: notes.value.trim()
  }
}

function fail(message: string) {
  error.value = message
}

function yesNoLabel(value: string) {
  if (value === 'yes') return t('worker.yes')
  if (value === 'no') return t('worker.no')
  return ''
}

function placeLabel(value: string) {
  if (value === 'own') return t('interview.own')
  if (value === 'rent') return t('interview.rent')
  if (value === 'staying_with_someone') return t('interview.staying')
  if (value === 'temporary') return t('interview.temporary')
  return ''
}

function mealsLabel(value: string) {
  if (value === 'three') return t('interview.mealsThree')
  if (value === 'two') return t('interview.mealsTwo')
  if (value === 'one') return t('interview.mealsOne')
  if (value === 'not_every_day') return t('interview.mealsNot')
  return ''
}

defineExpose({ attempt, fail })
</script>

<template>
  <div>
    <template v-if="readonly">
      <p><span class="label">{{ t('interview.place') }}</span> {{ placeLabel(place) }}</p>
      <p v-if="place === 'rent'"><span class="label">{{ t('interview.rentPerMonth') }}</span> {{ rent }}</p>
      <p v-if="place === 'rent'"><span class="label">{{ t('interview.behind') }}</span> {{ yesNoLabel(behind) }}</p>
      <p><span class="label">{{ t('interview.water') }}</span> {{ yesNoLabel(water) }}</p>
      <p><span class="label">{{ t('interview.electricity') }}</span> {{ yesNoLabel(electricity) }}</p>
      <p><span class="label">{{ t('interview.rooms') }}</span> {{ rooms }}</p>
      <p><span class="label">{{ t('interview.safe') }}</span> {{ yesNoLabel(safe) }}</p>
      <p v-if="safe === 'no'">{{ unsafe }}</p>
      <p><span class="label">{{ t('interview.meals') }}</span> {{ mealsLabel(meals) }}</p>
      <p><span class="label">{{ t('interview.basket') }}</span> {{ basket }}</p>
      <p><span class="label">{{ t('interview.notes') }}</span> {{ notes }}</p>
    </template>
    <template v-else>
      <label class="field">{{ t('interview.place') }}
        <select id="place" v-model="place">
          <option value="" />
          <option value="own">{{ t('interview.own') }}</option>
          <option value="rent">{{ t('interview.rent') }}</option>
          <option value="staying_with_someone">{{ t('interview.staying') }}</option>
          <option value="temporary">{{ t('interview.temporary') }}</option>
        </select>
      </label>
      <template v-if="place === 'rent'">
        <label class="field">{{ t('interview.rentPerMonth') }}
          <input id="rent-per-month" v-model="rent" type="text" inputmode="numeric" :aria-invalid="error === t('interview.rentInvalid')">
        </label>
        <label class="field">{{ t('interview.behind') }}
          <select id="behind-on-payments" v-model="behind">
            <option value="" />
            <option value="yes">{{ t('worker.yes') }}</option>
            <option value="no">{{ t('worker.no') }}</option>
          </select>
        </label>
      </template>
      <label class="field">{{ t('interview.water') }}
        <select id="has-water" v-model="water">
          <option value="" />
          <option value="yes">{{ t('worker.yes') }}</option>
          <option value="no">{{ t('worker.no') }}</option>
        </select>
      </label>
      <label class="field">{{ t('interview.electricity') }}
        <select id="has-electricity" v-model="electricity">
          <option value="" />
          <option value="yes">{{ t('worker.yes') }}</option>
          <option value="no">{{ t('worker.no') }}</option>
        </select>
      </label>
      <label class="field">{{ t('interview.rooms') }}
        <input id="sleeping-rooms" v-model="rooms" type="text" inputmode="numeric">
      </label>
      <label class="field">{{ t('interview.safe') }}
        <select id="safe" v-model="safe">
          <option value="" />
          <option value="yes">{{ t('worker.yes') }}</option>
          <option value="no">{{ t('worker.no') }}</option>
        </select>
      </label>
      <label v-if="safe === 'no'" class="field">{{ t('interview.unsafe') }}
        <textarea id="unsafe-detail" v-model="unsafe" rows="2" />
      </label>
      <label class="field">{{ t('interview.meals') }}
        <select id="meals" v-model="meals">
          <option value="" />
          <option value="three">{{ t('interview.mealsThree') }}</option>
          <option value="two">{{ t('interview.mealsTwo') }}</option>
          <option value="one">{{ t('interview.mealsOne') }}</option>
          <option value="not_every_day">{{ t('interview.mealsNot') }}</option>
        </select>
      </label>
      <label class="field">{{ t('interview.basket') }}
        <input id="basket" v-model="basket" type="text">
      </label>
      <label class="field">{{ t('interview.notes') }}
        <textarea id="house-notes" v-model="notes" rows="3" />
      </label>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
    </template>
  </div>
</template>
