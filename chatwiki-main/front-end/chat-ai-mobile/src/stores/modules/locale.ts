import { defineStore } from 'pinia'
import { Locale } from 'vant'
import { store } from '../index'
import zhCn from 'vant/es/locale/lang/zh-CN'
import enUS from 'vant/es/locale/lang/en-US'
import jaJP from 'vant/es/locale/lang/ja-JP'
import koKR from 'vant/es/locale/lang/ko-KR'
import { Storage } from '@/utils/Storage'
import type { LocaleState, LocaleDropdownType} from '@/locales/config'


const vantLocaleMap = {
  'zh-CN': zhCn,
  'en-US': enUS,
  'ja-JP': jaJP,
  'ko-KR': koKR
}

export const useLocaleStore = defineStore('locales', {
  state: (): LocaleState => {
    return {
      currentLocale: {
        lang: Storage.get('lang') || 'zh-CN',
        vantLocale: vantLocaleMap[Storage.get('lang') || 'zh-CN']
      },
      // 多语言
      localeMap: [
        {
          lang: 'zh-CN',
          name: '简体中文'
        },
        {
          lang: 'en-US',
          name: 'English'
        },
        {
          lang: 'ja-JP',
          name: '日本語'
        },
        {
          lang: 'ko-KR',
          name: '한국어'
        }
      ]
    }
  },
  getters: {
    getCurrentLocale(): LocaleDropdownType {
      return this.currentLocale
    },
    getLocaleMap(): LocaleDropdownType[] {
      return this.localeMap
    },
  },
  actions: {
    setCurrentLocale(localeMap) {
      // this.locale = Object.assign(this.locale, localeMap)
      this.currentLocale.lang = localeMap?.lang
      this.currentLocale.vantLocale = vantLocaleMap[localeMap?.lang]

      Locale.use(localeMap?.lang, this.currentLocale.vantLocale)

      Storage.set('lang', localeMap?.lang)
    }
  }
})

export const useLocaleStoreWithOut = () => {
  return useLocaleStore(store)
}
