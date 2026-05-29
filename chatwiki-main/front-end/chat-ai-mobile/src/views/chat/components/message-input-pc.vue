<template>
  <div class="message-input-wrapper"  :class="{ 'is-set': props.value }">
    <FileToolbar :file-list="fileList" @delete="deleteFile" v-if="fileList.length > 0" />
    <div class="message-input-box">
      <ATextarea
        ref="pcTextareaRef"
        class="message-input"
        :value="props.value"
        :auto-size="{ minRows: 2, maxRows: 5 }"
        :placeholder="t('ph_input_message_with_shift')"
        @change="onChange"
        @keydown="handleKeydown"
      />
    </div>

    <div class="message-action">
      <div class="select-file-btn" @click="openFileDialog" v-if="props.showUpload">
        <svg-icon class="select-file-icon" name="circularNeedle"></svg-icon>
        <span class="file-number" :class="{ big: fileList.length > 9 }" v-if="fileList.length > 0">{{ fileList.length }}</span>
      </div>

      <button ref="emojiBtnRef" class="emoji-btn" @click.stop="toggleEmoji" :title="t('emoji')">😊</button>

      <button
        class="send-msg-btn"
        :class="{ loading: props.loading }"
        :disabled="disabled"
        @click="sendMessage"
      >
        <ASpin size="small" class="loading-action" style="margin-right: 4px" v-if="props.loading" />
        <svg-icon class="paper-airplane" name="paper-airplane-new-active" v-else />
      </button>
    </div>

    <div v-if="showEmoji" class="emoji-panel" ref="emojiPanelRef" @click.stop>
      <div class="emoji-categories">
        <span
          v-for="(cat, idx) in emojiCategories"
          :key="idx"
          class="emoji-cat"
          :class="{ active: activeCategory === idx }"
          @click="activeCategory = idx"
        >
          {{ cat.icon }}
        </span>
      </div>
      <div class="emoji-grid">
        <span
          v-for="(emoji, eIdx) in [...emojiCategories[activeCategory].emojis]"
          :key="eIdx"
          class="emoji-item"
          @click="insertEmoji(emoji)"
        >
          {{ emoji }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, toRefs, computed, nextTick, onMounted, onUnmounted } from 'vue'
import { useChatStore } from '@/stores/modules/chat'
import { useUserStore } from '@/stores/modules/user'
import { Textarea as ATextarea, Spin as ASpin } from 'ant-design-vue'
import { showToast } from 'vant'
import { useI18n } from '@/hooks/web/useI18n'
import { useUpload } from '@/hooks/web/useUpload.js'
import { checkChatRequestPermission } from '@/api/robot/index'
import FileToolbar from './file-toolbar.vue'

const chatStore = useChatStore()
const userStore = useUserStore()
const { robot } = chatStore


const emit = defineEmits(['update:value', 'send', 'showLogin', 'update:fileList'])

const props = defineProps({
  value: {
    type: String,
    default: ''
  },
  loading: {
    type: Boolean,
    default: false
  },
  fileList: {
    type: Array,
    default: () => []
  },
  showUpload: {
    type: Boolean,
    default: false
  },
})

const { fileList } = toRefs(props)
const pcTextareaRef = ref(null)

// Emoji
const showEmoji = ref(false)
const activeCategory = ref(0)
const emojiPanelRef = ref(null)
const emojiBtnRef = ref(null)

const emojiCategories = [
  { icon: '😀', emojis: '😀😃😄😁😅😂🤣😊😇🙂😉😌😍🥰😘😗😙😚😋😛😝😜🤪🤨🧐🤓😎🤩🥳' },
  { icon: '👍', emojis: '👍👎👏🙌🤝💪👆👇👉👈✌️🤞🤟🤘👌🤌🤏' },
  { icon: '❤️', emojis: '❤️🧡💛💚💙💜🖤🤍🤎💔❣️💕💞💓💗💖💘💝' },
  { icon: '🔥', emojis: '🔥⭐🌟✨💫🎉🎊🎈🎂🎁🏆🥇🥈🥉' },
  { icon: '✅', emojis: '✅❌❓❗⚠️💯🔴🟠🟡🟢🔵🟣⚪🟤' },
]

const getTextareaEl = () => {
  const el = pcTextareaRef.value?.$el
  if (!el) return null
  if (el.tagName === 'TEXTAREA') return el
  return el.querySelector('textarea')
}

const toggleEmoji = () => {
  showEmoji.value = !showEmoji.value
}

const insertEmoji = (emoji) => {
  const textarea = getTextareaEl()
  if (!textarea) return

  const start = textarea.selectionStart
  const end = textarea.selectionEnd
  const currentValue = props.value
  const newValue = currentValue.slice(0, start) + emoji + currentValue.slice(end)

  emit('update:value', newValue)

  nextTick(() => {
    textarea.focus()
    const newCursor = start + [...emoji].length
    textarea.setSelectionRange(newCursor, newCursor)
    const event = new Event('input', { bubbles: true })
    textarea.dispatchEvent(event)
  })

  showEmoji.value = false
}

const handleClickOutside = (event) => {
  if (showEmoji.value && emojiPanelRef.value && emojiBtnRef.value) {
    if (!emojiPanelRef.value.contains(event.target) && !emojiBtnRef.value.contains(event.target)) {
      showEmoji.value = false
    }
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})

const { t } = useI18n('views.chat.components.message-input-pc')

const { openFileDialog } = useUpload({
  limit: 10,
  maxSize: 10,
  category: 'chat_image',
  fileList: fileList,
  multiple: true,
  accept: 'image/bmp,image/jpeg,image/png,image/tiff,image/heic,image/gif,image/webp',
  extraData: {
    robot_key: robot.robot_key,
    openid: robot.openid
  }
})

const deleteFile = (index) => {
  const newFileList = props.fileList.filter((_, i) => i !== index);
  emit('update:fileList', newFileList);
}

const disabled = computed(() => {
  if(props.fileList.length > 0){
    return false
  }

  return props.loading || props.value.trim().length === 0
})

const onChange = (event) => {
  emit('update:value', event.target.value)
}

const sendMessage = async () => {
  emit('send', props.value)
}

const handleKeydown = (event) => {
  if (event.key === 'Enter' && !event.shiftKey) {
    if (!event.target.value) {
      return
    }
    event.preventDefault()
    event.stopPropagation()
    sendMessage()
  } else if (event.key === 'Enter' && event.shiftKey) {
    emit('update:value', event.target.value)
  }
}

const handleSetValue = (data) => {
  emit('update:value', data)
}

defineExpose({
  handleSetValue,
  sendMessage
})
</script>


<style lang="less" scoped>
.message-input-wrapper {
  position: relative;
  max-width: 736px;
  margin: 0 auto;
  padding: 12px;
  border-radius: 20px;
  border: 1px solid #d9d9d9;
  overflow: hidden;
  background-color: #fff;
  transition: all 0.2s;

  &.is-set {
    border: 1px solid #2475fc;
  }

  .message-input-box {
    padding: 0 0 12px 0;
  }

  .message-input {
    width: 100%;
    padding: 0 12px;
    line-height: 24px;
    border: none !important;
    outline: none !important;
    resize: none !important;
    box-shadow: none !important;
  }

  .message-action {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    padding: 0 12px 12px 12px;

    .emoji-btn {
      width: 32px;
      height: 32px;
      padding: 0;
      margin-right: 8px;
      border-radius: 50%;
      border: 1px solid #f0f0f0;
      background: #fff;
      font-size: 18px;
      cursor: pointer;
      transition: all 0.2s;
      display: flex;
      align-items: center;
      justify-content: center;

      &:hover {
        background: #e4e6eb;
      }
    }
  }

  .send-msg-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    padding: 0;
    font-size: 14px;
    font-weight: 400;
    border-radius: 4px;
    border: none;
    cursor: pointer;
    transition: all 0.2s;
    color: #2475fc;
    border-radius: 50%;
    background: none;

    &:hover {
      opacity: 0.8;
    }
    &:disabled {
      opacity: 0.5;
    }
    .paper-airplane {
      font-size: 32px;
    }

    &.loading {
      background-color: #2475fc;
    }
    .loading-action{
      display: flex;
      align-items: center;
      justify-content: center;
      margin-left: 3px;
      ::v-deep(.ant-spin-dot-item) {
        background-color: #fff;
      }
    }
    
  }

  .select-file-btn {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    padding: 0;
    margin-right: 8px;
    border-radius: 50%;
    border: none;
    background: #fff;
    cursor: pointer;
    transition: all 0.2s;
    border: 1px solid #f0f0f0;

    &:hover {
      background: #e4e6eb;
    }

    .select-file-icon {
      font-size: 16px;
      color: #595959;
    }

    .file-number{
      position: absolute;
      right: -8px;
      top: -8px;
      width: 16px;
      height: 16px;
      border-radius: 50%;
      background: #f00;
      color: #fff;
      font-size: 12px;
      font-weight: 400;
      display: flex;
      align-items: center;
      justify-content: center;

      &.big{
        width: auto;
        padding: 0 4px;
        border-radius: 12px;
      }
    }
  }

  .emoji-panel {
    position: absolute;
    bottom: 100%;
    right: 12px;
    margin-bottom: 8px;
    width: 360px;
    max-height: 300px;
    background: #fff;
    border-radius: 12px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    overflow: hidden;
    z-index: 1000;

    .emoji-categories {
      display: flex;
      padding: 8px 12px 0;
      border-bottom: 1px solid #f0f0f0;

      .emoji-cat {
        width: 36px;
        height: 36px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 18px;
        cursor: pointer;
        border-radius: 8px 8px 0 0;
        transition: all 0.15s;

        &:hover {
          background: #f5f5f5;
        }

        &.active {
          background: #e8f0fe;
          border-bottom: 2px solid #2475fc;
        }
      }
    }

    .emoji-grid {
      display: grid;
      grid-template-columns: repeat(9, 1fr);
      gap: 2px;
      padding: 8px;
      max-height: 240px;
      overflow-y: auto;

      .emoji-item {
        width: 32px;
        height: 32px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 20px;
        cursor: pointer;
        border-radius: 6px;
        transition: all 0.15s;

        &:hover {
          background: #e8f0fe;
          transform: scale(1.2);
        }
      }
    }
  }
}
</style>