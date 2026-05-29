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
const robotKey = computed(() => String(route.query.robot_key || ''))
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

function openChat(targetRobotKey: string, replace = false) {
  const query = {
    ...route.query,
    robot_key: targetRobotKey
  }
  if (replace) {
    router.replace({ path: '/chat', query })
    return
  }
  router.push({ path: '/chat', query })
}

async function loadPortal() {
  if (robotKey.value) {
    openChat(robotKey.value, true)
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
      openChat(defaultRobotKey, true)
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
      <div class="hero-top">
        <div v-if="companyAvatar" class="brand-avatar">
          <img :src="companyAvatar" :alt="companyName">
        </div>
        <div v-else class="brand-avatar brand-avatar-fallback">
          {{ companyName.slice(0, 1) }}
        </div>
        <div class="hero-copy">
          <div class="eyebrow">AI Support</div>
          <h1>{{ companyName }}</h1>
          <p>Pick a support bot and start a sales, service, or FAQ conversation right away.</p>
        </div>
      </div>
      <div class="hero-tags">
        <span>AI answers</span>
        <span>Knowledge replies</span>
        <span>Ongoing chat</span>
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

      <div v-else class="robot-list">
        <article v-for="robot in robots" :key="robot.id" class="robot-card">
          <div class="robot-head">
            <img v-if="robot.robot_avatar" :src="normalizeAsset(robot.robot_avatar)" :alt="robot.robot_name">
            <div v-else class="robot-avatar-fallback">{{ robot.robot_name.slice(0, 1) }}</div>
            <div class="robot-info">
              <h2>{{ robot.robot_name }}</h2>
              <p>{{ robot.robot_intro || 'AI conversation is enabled and ready for customer support.' }}</p>
            </div>
          </div>
          <button class="enter-btn" @click="openChat(robot.robot_key)">
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
  padding: 18px 14px 24px;
  background:
    radial-gradient(circle at top right, rgba(40, 112, 255, 0.18), transparent 34%),
    linear-gradient(180deg, #f4f8ff 0%, #eef4f6 100%);
}

.hero-card {
  padding: 20px;
  border-radius: 26px;
  background: rgba(255, 255, 255, 0.94);
  box-shadow: 0 18px 48px rgba(30, 55, 90, 0.12);
}

.hero-top {
  display: flex;
  gap: 14px;
  align-items: center;
}

.brand-avatar,
.brand-avatar-fallback {
  width: 64px;
  height: 64px;
  border-radius: 20px;
  overflow: hidden;
  background: linear-gradient(135deg, #173256 0%, #2b75ff 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 26px;
  font-weight: 700;
  flex-shrink: 0;
}

.brand-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.eyebrow {
  display: inline-flex;
  padding: 5px 10px;
  border-radius: 999px;
  background: #e8f0ff;
  color: #275fda;
  font-size: 12px;
  font-weight: 700;
}

.hero-copy h1 {
  margin: 10px 0 8px;
  font-size: 28px;
  line-height: 1.15;
  color: #142033;
}

.hero-copy p {
  margin: 0;
  color: #55657d;
  line-height: 1.7;
  font-size: 14px;
}

.hero-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 16px;
}

.hero-tags span {
  padding: 8px 12px;
  border-radius: 999px;
  background: #f4f8fb;
  color: #27415a;
  font-size: 13px;
}

.portal-content {
  margin-top: 16px;
}

.panel-state {
  padding: 30px 18px;
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 14px 36px rgba(30, 55, 90, 0.1);
  text-align: center;
  color: #1d2b3f;
  line-height: 1.8;
}

.panel-state-error {
  color: #b94747;
}

.state-tip {
  margin-top: 8px;
  font-size: 13px;
  color: #6c7a90;
}

.robot-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.robot-card {
  padding: 18px;
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 14px 36px rgba(30, 55, 90, 0.1);
}

.robot-head {
  display: grid;
  grid-template-columns: 56px minmax(0, 1fr);
  gap: 14px;
}

.robot-head img,
.robot-avatar-fallback {
  width: 56px;
  height: 56px;
  border-radius: 18px;
  background: #edf3ff;
  color: #2e5fd0;
  object-fit: cover;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  font-weight: 700;
}

.robot-info h2 {
  margin: 0 0 6px;
  color: #152238;
  font-size: 20px;
}

.robot-info p {
  margin: 0;
  color: #5d6c83;
  line-height: 1.7;
  font-size: 14px;
}

.enter-btn {
  width: 100%;
  margin-top: 16px;
  border: 0;
  border-radius: 16px;
  padding: 14px 16px;
  background: linear-gradient(135deg, #2a69ff 0%, #0db596 100%);
  color: #fff;
  font-size: 15px;
  font-weight: 700;
}
</style>
