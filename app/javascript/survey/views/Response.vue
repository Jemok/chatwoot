<script>
import { useAlert } from 'dashboard/composables';
import Branding from 'shared/components/Branding.vue';
import Spinner from 'shared/components/Spinner.vue';
import Rating from 'survey/components/Rating.vue';
import Feedback from 'survey/components/Feedback.vue';
import Banner from 'survey/components/Banner.vue';
import StarRating from 'shared/components/StarRating.vue';
import { getSurveyDetails, updateSurvey } from 'survey/api/survey';

import { CSAT_DISPLAY_TYPES } from 'shared/constants/messages';

export default {
  name: 'Response',
  components: {
    Branding,
    Rating,
    Spinner,
    Banner,
    Feedback,
    StarRating,
  },
  data() {
    return {
      surveyDetails: null,
      isLoading: false,
      errorMessage: null,
      selectedRating: null,
      feedbackMessage: '',
      selectedNpsScore: null,
      npsComment: '',
      npsResponse: null,
      isUpdating: false,
      logo: '',
      inboxName: '',
      displayType: CSAT_DISPLAY_TYPES.EMOJI,
      messageContent: '',
    };
  },
  computed: {
    surveyId() {
      const pageURL = window.location.href;
      return pageURL.substring(pageURL.lastIndexOf('/') + 1);
    },
    isRatingSubmitted() {
      return this.surveyDetails && this.surveyDetails.rating;
    },
    isFeedbackSubmitted() {
      return this.surveyDetails && this.surveyDetails.feedback_message;
    },
    isNpsSubmitted() {
      return this.npsResponse && this.npsResponse.score !== undefined;
    },
    enableNpsForm() {
      return this.isRatingSubmitted && !this.isNpsSubmitted;
    },
    isButtonDisabled() {
      return !(this.selectedRating && this.feedback);
    },
    isNpsButtonDisabled() {
      return this.selectedNpsScore === null || this.isUpdating;
    },
    npsScores() {
      return Array.from({ length: 11 }, (_, index) => index);
    },
    isEmojiType() {
      return this.displayType === CSAT_DISPLAY_TYPES.EMOJI;
    },
    isStarType() {
      return this.displayType === CSAT_DISPLAY_TYPES.STAR;
    },
    shouldShowBanner() {
      return this.isRatingSubmitted || this.errorMessage;
    },
    enableFeedbackForm() {
      return !this.isFeedbackSubmitted && this.isRatingSubmitted;
    },
    shouldShowErrorMessage() {
      return !!this.errorMessage;
    },
    shouldShowSuccessMessage() {
      return !!this.isRatingSubmitted;
    },
    message() {
      if (this.errorMessage) {
        return this.errorMessage;
      }
      return this.$t('SURVEY.RATING.SUCCESS_MESSAGE');
    },
  },
  async mounted() {
    this.getSurveyDetails();
  },
  methods: {
    selectRating(rating) {
      this.selectedRating = rating;
      this.updateSurveyDetails();
    },
    sendFeedback(message) {
      this.feedbackMessage = message;
      this.updateSurveyDetails();
    },
    async getSurveyDetails() {
      this.isLoading = true;
      try {
        const result = await getSurveyDetails({ uuid: this.surveyId });
        this.logo = result.data.inbox_avatar_url;
        this.inboxName = result.data.inbox_name;
        this.surveyDetails = result?.data?.csat_survey_response;
        this.npsResponse = result?.data?.nps_response;
        this.selectedRating = this.surveyDetails?.rating;
        this.feedbackMessage = this.surveyDetails?.feedback_message || '';
        this.selectedNpsScore = this.npsResponse?.score ?? null;
        this.npsComment = this.npsResponse?.comment || '';
        this.displayType = result.data.display_type || CSAT_DISPLAY_TYPES.EMOJI;
        this.messageContent =
          result.data.content ||
          this.$t('SURVEY.DESCRIPTION', { inboxName: this.inboxName });
        this.setLocale(result.data.locale);
      } catch (error) {
        const errorMessage = error?.response?.data?.message;
        this.errorMessage = errorMessage || this.$t('SURVEY.API.ERROR_MESSAGE');
      } finally {
        this.isLoading = false;
      }
    },
    async updateSurveyDetails() {
      this.isUpdating = true;
      try {
        const data = {
          message: {
            submitted_values: {
              csat_survey_response: {
                rating: this.selectedRating,
                feedback_message: this.feedbackMessage,
              },
            },
          },
        };
        const response = await updateSurvey({
          uuid: this.surveyId,
          data,
        });
        this.surveyDetails = {
          rating: this.selectedRating,
          feedback_message: this.feedbackMessage,
        };
        this.npsResponse = response?.data?.nps_response || this.npsResponse;
      } catch (error) {
        const errorMessage = error?.response?.data?.error;
        this.errorMessage = errorMessage || this.$t('SURVEY.API.ERROR_MESSAGE');
        useAlert(this.errorMessage);
      } finally {
        this.isUpdating = false;
      }
    },
    selectNpsScore(score) {
      this.selectedNpsScore = score;
    },
    async submitNps() {
      this.isUpdating = true;
      try {
        const response = await updateSurvey({
          uuid: this.surveyId,
          data: {
            message: {
              submitted_values: {
                csat_survey_response: {
                  rating: this.selectedRating,
                  feedback_message: this.feedbackMessage,
                },
                nps_response: {
                  id: this.npsResponse?.id,
                  score: this.selectedNpsScore,
                  comment: this.npsComment,
                },
              },
            },
          },
        });
        this.npsResponse = response?.data?.nps_response || {
          score: this.selectedNpsScore,
          comment: this.npsComment,
        };
      } catch (error) {
        const errorMessage = error?.response?.data?.error;
        this.errorMessage = errorMessage || this.$t('SURVEY.API.ERROR_MESSAGE');
        useAlert(this.errorMessage);
      } finally {
        this.isUpdating = false;
      }
    },
    setLocale(locale) {
      this.$root.$i18n.locale = locale || 'en';
    },
  },
};
</script>

<template>
  <div
    v-if="isLoading"
    class="flex items-center justify-center flex-1 h-full min-h-screen bg-n-background"
  >
    <Spinner size="" />
  </div>
  <div
    v-else
    class="flex items-center justify-center w-full h-full min-h-screen overflow-auto bg-n-background"
  >
    <div
      class="flex flex-col w-full h-full bg-n-solid-1 rounded-lg border border-solid border-n-weak shadow-md lg:w-2/5 lg:h-auto"
    >
      <div class="w-full px-12 pt-12 pb-6 m-auto my-0">
        <img v-if="logo" :src="logo" alt="Chatwoot logo" class="mb-6 logo" />
        <p
          v-if="!isRatingSubmitted"
          class="mb-8 text-lg leading-relaxed text-n-slate-12"
        >
          {{ messageContent }}
        </p>
        <Banner
          v-if="shouldShowBanner"
          :show-success="shouldShowSuccessMessage"
          :show-error="shouldShowErrorMessage"
          :message="message"
        />
        <label
          v-if="!isRatingSubmitted"
          class="mb-4 text-base font-medium text-n-slate-11"
        >
          {{ $t('SURVEY.RATING.LABEL') }}
        </label>
        <Rating
          v-if="isEmojiType"
          :selected-rating="selectedRating"
          @select-rating="selectRating"
        />
        <StarRating
          v-if="isStarType"
          :selected-rating="selectedRating"
          :is-disabled="isRatingSubmitted"
          class="[&>button>span]:text-4xl !justify-start !px-0"
          @select-rating="selectRating"
        />
        <Feedback
          v-if="enableFeedbackForm"
          :is-updating="isUpdating"
          :is-button-disabled="isButtonDisabled"
          :selected-rating="selectedRating"
          @send-feedback="sendFeedback"
        />
        <div v-if="enableNpsForm" class="mt-8">
          <label class="mb-3 block text-base font-medium text-n-slate-12">
            {{ $t('SURVEY.NPS.LABEL') }}
          </label>
          <p class="mb-4 text-sm text-n-slate-11">
            {{ $t('SURVEY.NPS.DESCRIPTION') }}
          </p>
          <div class="mb-5 grid grid-cols-5 gap-2 sm:grid-cols-10">
            <button
              v-for="score in npsScores"
              :key="score"
              type="button"
              class="rounded-lg border px-3 py-2 text-sm font-semibold transition-colors"
              :class="[
                selectedNpsScore === score
                  ? 'border-n-brand bg-n-brand text-white'
                  : 'border-n-weak bg-n-background text-n-slate-12 hover:bg-n-alpha-2',
              ]"
              @click="selectNpsScore(score)"
            >
              {{ score }}
            </button>
          </div>
          <textarea
            v-model="npsComment"
            class="mb-4 min-h-[96px] w-full rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            :placeholder="$t('SURVEY.NPS.PLACEHOLDER')"
          />
          <button
            type="button"
            class="rounded-lg bg-n-brand px-4 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="isNpsButtonDisabled"
            @click="submitNps"
          >
            {{ $t('SURVEY.NPS.BUTTON_TEXT') }}
          </button>
        </div>
        <p v-if="isNpsSubmitted" class="mt-6 text-sm text-n-slate-11">
          {{ $t('SURVEY.NPS.SUCCESS_MESSAGE') }}
        </p>
      </div>
      <div class="mb-3">
        <Branding />
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.logo {
  max-height: 3rem;
}
</style>
