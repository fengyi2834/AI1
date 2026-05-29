<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getClientSideRobotPortal } from '@/api/client-side'

interface PortalRobot {
  id: number
  robot_key: string
  robot_name: string
  robot_intro: string
  robot_avatar: string
}

interface PortalCompany {
  id?: number
  name?: string
  avatar?: string
}

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const error = ref('')
const robots = ref<PortalRobot[]>([])
const company = ref<PortalCompany>({})

const adminUserId = computed(() => String(route.query.admin_user_id || ''))
const hasRobotKey = computed(() => String(route.query.robot_key || ''))
const companyName = computed(() => company.value.name || 'AI Support Center')
const companyAvatar = computed(() => normalizeAsset(company.value.avatar || robots.value[0]?.robot_avatar || ''))

function normalizeAsset(path?: string) {
  if (!path) {
    return ''
  }
  if (/^https?:\/\//.test(path)) {
    return path
  }
  return path.startsWith('/') ? `${window.location.origin}${path}` : `${window.location.origin}/${path}`
}

function jumpToChat(robotKey: string, replace = false) {
  const query = {
    ...route.query,
    robot_key: robotKey
  }
  if (replace) {
    router.replace({ path: '/chat', query })
    return
  }
  router.push({ path: '/chat', query })
}

async function loadPortal() {
  if (hasRobotKey.value) {
    jumpToChat(hasRobotKey.value, true)
    return
  }
  if (!adminUserId.value) {
    error.value = 'Missing admin_user_id parameter.'
    return
  }

  loading.value = true
  error.value = ''

  try {
    const res = await getClientSideRobotPortal({ admin_user_id: adminUserId.value })
    const data = res?.data || {}
    robots.value = Array.isArray(data.list) ? data.list : []
    company.value = data.company || {}

    const defaultRobotKey = String(data.default_robot_key || robots.value[0]?.robot_key || '')
    if (robots.value.length === 1 && defaultRobotKey) {
      jumpToChat(defaultRobotKey, true)
    }
  } catch (err: any) {
    error.value = err?.message || 'Failed to load the support portal.'
  } finally {
    loading.value = false
  }
}

onMounted(loadPortal)
</script>

<template>
  <main class="portal-page">
    <section class="hero-card">
      <div class="hero-copy">
        <div class="eyebrow">AI Customer Service MVP</div>
        <h1>{{ companyName }}</h1>
        <p>
          A lightweight AI support portal for presales, service, and FAQ scenarios.
        </p>
        <div class="hero-tags">
          <span>24/7 AI support</span>
          <span>Knowledge answers</span>
          <span>Multi-bot entry</span>
        </div>
      </div>
      <div class="hero-brand">
        <div v-if="companyAvatar" class="brand-avatar">
          <img :src="companyAvatar" :alt="companyName">
        </div>
        <div v-else class="brand-avatar brand-avatar-fallback">
          {{ companyName.slice(0, 1) }}
        </div>
        <div class="brand-title">{{ companyName }}</div>
        <div class="brand-subtitle">Choose a support bot to start chatting.</div>
      </div>
    </section>

    <section class="portal-content">
      <div v-if="loading" class="panel-state">
        Loading support bots...
      </div>

      <div v-else-if="error" class="panel-state panel-state-error">
        <div>{{ error }}</div>
        <div class="state-tip">Example: `/?admin_user_id=1`</div>
      </div>

      <div v-else-if="robots.length === 0" class="panel-state">
        <div>No chat-ready support bots are available yet.</div>
        <div class="state-tip">Create a chat bot and finish model setup in the admin console first.</div>
      </div>

      <div v-else class="robot-grid">
        <article v-for="robot in robots" :key="robot.id" class="robot-card">
          <div class="robot-head">
            <img v-if="robot.robot_avatar" :src="normalizeAsset(robot.robot_avatar)" :alt="robot.robot_name">
            <div v-else class="robot-avatar-fallback">{{ robot.robot_name.slice(0, 1) }}</div>
            <div>
              <h2>{{ robot.robot_name }}</h2>
              <p>{{ robot.robot_intro || 'AI conversation is enabled and ready for customer support.' }}</p>
            </div>
          </div>
          <button class="enter-btn" @click="jumpToChat(robot.robot_key)">
            Start Chat
          </button>
        </article>
      </div>
    </section>
  </main>
</template>

<style scoped>
.portal-page {
  min-height: 100vh;
  padding: 40px 24px 32px;
  background:
    radial-gradient(circle at top left, rgba(64, 136, 255, 0.18), transparent 30%),
    radial-gradient(circle at bottom right, rgba(12, 184, 145, 0.16), transparent 28%),
    linear-gradient(180deg, #f3f7ff 0%, #eef3f7 100%);
  color: #142033;
}

.hero-card {
  max-width: 1180px;
  margin: 0 auto 24px;
  padding: 32px;
  border-radius: 28px;
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(14px);
  box-shadow: 0 20px 60px rgba(30, 55, 90, 0.12);
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(280px, 360px);
  gap: 24px;
  align-items: center;
}

.eyebrow {
  display: inline-flex;
  padding: 8px 14px;
  border-radius: 999px;
  background: #e8f0ff;
  color: #2f63d8;
  font-size: 13px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.hero-copy h1 {
  margin: 16px 0 12px;
  font-size: clamp(32px, 4vw, 54px);
  line-height: 1.05;
}

.hero-copy p {
  max-width: 680px;
  margin: 0;
  font-size: 17px;
  line-height: 1.8;
  color: #53627a;
}

.hero-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-top: 22px;
}

.hero-tags span {
  padding: 10px 14px;
  border-radius: 999px;
  background: #f4f8fb;
  color: #24415f;
  font-size: 14px;
}

.hero-brand {
  padding: 24px;
  border-radius: 24px;
  background: linear-gradient(160deg, #122033 0%, #244d7a 100%);
  color: #fff;
  min-height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.brand-avatar,
.brand-avatar-fallback {
  width: 82px;
  height: 82px;
  border-radius: 24px;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.14);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 34px;
  font-weight: 700;
}

.brand-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.brand-title {
  margin-top: 18px;
  font-size: 24px;
  font-weight: 700;
}

.brand-subtitle {
  margin-top: 8px;
  color: rgba(255, 255, 255, 0.75);
  line-height: 1.7;
}

.portal-content {
  max-width: 1180px;
  margin: 0 auto;
}

.panel-state {
  padding: 44px 28px;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.94);
  box-shadow: 0 18px 48px rgba(30, 55, 90, 0.1);
  text-align: center;
  font-size: 18px;
}

.panel-state-error {
  color: #b94747;
}

.state-tip {
  margin-top: 10px;
  font-size: 14px;
  color: #6c7a90;
}

.robot-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 18px;
}

.robot-card {
  padding: 24px;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 18px 48px rgba(30, 55, 90, 0.1);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.robot-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 24px 56px rgba(30, 55, 90, 0.16);
}

.robot-head {
  display: grid;
  grid-template-columns: 64px minmax(0, 1fr);
  gap: 16px;
  align-items: start;
}

.robot-head img,
.robot-avatar-fallback {
  width: 64px;
  height: 64px;
  border-radius: 18px;
  object-fit: cover;
  background: #edf3ff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  font-weight: 700;
  color: #2e5fd0;
}

.robot-head h2 {
  margin: 0 0 8px;
  font-size: 22px;
}

.robot-head p {
  margin: 0;
  line-height: 1.75;
  color: #5e6d84;
}

.enter-btn {
  width: 100%;
  margin-top: 22px;
  border: 0;
  border-radius: 16px;
  padding: 14px 18px;
  background: linear-gradient(135deg, #2a69ff 0%, #0db596 100%);
  color: #fff;
  font-size: 16px;
  font-weight: 700;
  cursor: pointer;
}

@media (max-width: 860px) {
  .portal-page {
    padding: 20px 14px 24px;
  }

  .hero-card {
    grid-template-columns: 1fr;
    padding: 24px;
  }

  .hero-copy p {
    font-size: 15px;
  }
}
</style>
