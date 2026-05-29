<style lang="less" scoped>
.message-input-wrapper {
  margin: 0 12px;
  position: relative;
}
.message-input-container {
  position: relative;
  width: 100%;
  padding: 10px;
  margin-bottom: 0px;
  border-radius: 12px;
  transition: all 0.2s;
  background: #fff;
  border: 1px solid #d9d9d9;
  box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.08);

  &.is-set {
    border: 1px solid #2475fc;
  }

  .message-input-body {
    display: flex;
    justify-content: center;
    align-items: flex-end;
  }

  .message-input {
    flex: 1;
    display: flex;
    position: relative;
    line-height: 22px;
    padding: 5px 8px 5px 0;

    .text-input {
      line-height: 22px;
      height: 22px;
      padding: 0;
      flex: 1;
      margin: 0;
      font-size: 14px;
      font-weight: 400;
      color: rgb(26, 26, 26);
      background: none;
      outline: none;
      resize: none;
      border: none;
      transition: height 0.1s ease-in-out;
      overflow: hidden;
      white-space: pre-wrap; /* 保持内容的换行，并允许自动换行 */

      &::placeholder {
        font-size: 16px;
        font-weight: 400;
        color: rgb(191, 191, 191);
      }
    }

    /* 滚动条样式 */
    .text-input::-webkit-scrollbar {
      width: 4px; /*  设置纵轴（y轴）轴滚动条 */
      height: 4px; /*  设置横轴（x轴）轴滚动条 */
    }
    /* 滚动条滑块（里面小方块） */
    .text-input::-webkit-scrollbar-thumb {
      cursor: pointer;
      border-radius: 5px;
      background: transparent;
    }
    /* 滚动条轨道 */
    .text-input::-webkit-scrollbar-track {
      border-radius: 5px;
      background: transparent;
    }

    /* hover时显色 */
    .text-input:hover::-webkit-scrollbar-thumb {
      background: rgba(0, 0, 0, 0.2);
    }
    .text-input:hover::-webkit-scrollbar-track {
      background: rgba(0, 0, 0, 0.1);
    }
  }

  .message-action {
    display: flex;
    align-items: center;
    justify-content: center;

    .emoji-btn {
      width: 32px;
      height: 32px;
      padding: 0;
      margin-right: 4px;
      border-radius: 50%;
      border: none;
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

    .send-btn {
      padding: 0;
      width: 32px;
      height: 32px;
      padding: 0;
      border-radius: 50%;
      font-size: 32px;
      color: #b3b3b3;
      background: none;
      border: none;
      transition: all 0.2s;
      &.send-btn-active {
        color: #2475fc;
        cursor: pointer;
      }

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

      .file-number {
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

        &.big {
          width: auto;
          padding: 0 4px;
          border-radius: 12px;
        }
      }
    }
  }
}

.emoji-panel {
    position: absolute;
    bottom: 100%;
    right: 0;
    margin-bottom: 8px;
    width: 320px;
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
</style>

<template>
  <div class="message-input-wrapper">
    <div class="message-input-container" :class="{ 'is-set': props.value }">
      <FileToolbar :file-list="fileList" v-if="fileList.length > 0" />
      <div class="message-input-body">
        <div class="message-input">
          <textarea
            ref="messageTextarea"
            :style="{ height: inputHeight + 'px' }"
            class="text-input"
            :value="props.value"
            :placeholder="t('ph_input_message')"
            @change="onChange"
            @input="onInput"
            @keydown.enter="handleEnter"
            @focus="onFocus"
            @blur="onBlur"
          ></textarea>
        </div>

        <div class="message-action">
          <div class="select-file-btn" @click="openFileDialog" v-if="props.showUpload">
            <svg-icon class="select-file-icon" name="circularNeedle"></svg-icon>
            <span class="file-number" :class="{ big: fileList.length > 9 }" v-if="fileList.length > 0">{{ fileList.length }}</span>
          </div>

          <button ref="emojiBtnRef" class="emoji-btn" @click.stop="toggleEmoji" :title="t('emoji')">😊</button>

          <button
            class="send-btn"
            :class="{ loading: props.loading }"
            :disabled="disabled"
            @click="sendMessage"
          >
            <van-loading type="spinner" v-if="props.loading" size="16px" />
            <svg-icon class="paper-airplane" name="paper-airplane-new-active" v-else></svg-icon>
          </button>
        </div>
      </div>
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
import { ref, toRefs, computed, watch, nextTick, onMounted, onUnmounted  } from 'vue'
import calcTextareaHeight from '@/utils/calcTextareaHeight'
import { useChatStore } from '@/stores/modules/chat'
import { useUserStore } from '@/stores/modules/user'
import { showToast } from 'vant'
import { useI18n } from '@/hooks/web/useI18n'
import { useUpload } from '@/hooks/web/useUpload.js'
import FileToolbar from './file-toolbar.vue'

const chatStore = useChatStore()
const userStore = useUserStore()
const { robot } = chatStore
import { checkChatRequestPermission } from '@/api/robot/index'

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

const { t } = useI18n('views.chat.components.message-input')

const { fileList } = toRefs(props)
const messageTextarea = ref(null)

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

const toggleEmoji = () => {
  showEmoji.value = !showEmoji.value
}

const insertEmoji = (emoji) => {
  const textarea = messageTextarea.value
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

const disabled = computed(() => {
  if(props.fileList.length > 0){
    return false
  }

  return props.loading || props.value.trim().length === 0
})


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

const onChange = (event) => {
  emit('update:value', event.target.value)
}

const inputHeight = ref(22)
const inputMaxHeight = 5 * 22
const setInputHeight = (value) => {
  if (!value) {
    // 如果值为空，重置为初始高度
    inputHeight.value = 22
    if (messageTextarea.value) {
      messageTextarea.value.style.overflow = 'hidden'
    }
  } else {
    // 如果值不为空，重新计算高度
    nextTick(() => {
      let newHeight = calcTextareaHeight(messageTextarea.value).height || 22
      newHeight = parseInt(newHeight)

      if (newHeight >= inputMaxHeight) {
        inputHeight.value = inputMaxHeight
        if (messageTextarea.value) {
          messageTextarea.value.style.overflow = 'auto'
        }
      } else {
        inputHeight.value = newHeight
        if (messageTextarea.value) {
          messageTextarea.value.style.overflow = 'hidden'
        }
      }
    })
  }
}

const onInput = (event) => {
  onChange(event)

  // setInputHeight(event.target.value)
}

// 监听 props.value 变化，当值改变时调整高度
watch(() => props.value, (newValue) => {
  setInputHeight(newValue)
}, { immediate: false })

const sendMessage = async () => {
  emit('send', props.value)
}

const handleEnter = (event) => {
  const target = event.target
  
  if (event.shiftKey) {
    emit('update:value', event.target.value)
  }else{
    if (!event.target.value) {
      return
    }

    event.preventDefault()
    event.stopPropagation()

    sendMessage()
  }
}

const onFocus = (event) => {
  // event.target.parentNode.style.borderColor = '#2475FC'
}

const onBlur = (event) => {
  // event.target.parentNode.style.borderColor = '#DDD'
}

const handleSetValue = (data) => {
  emit('update:value', data)
}


defineExpose({
  handleSetValue,
  sendMessage
})
</script>
