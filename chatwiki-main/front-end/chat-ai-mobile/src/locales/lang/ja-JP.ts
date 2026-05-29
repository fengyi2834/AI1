import { genMessage } from '../helper'

const modulesFiles = import.meta.glob<Recordable>('./ja-JP/**/*.json', { eager: true })

export default {
  ...genMessage(modulesFiles, 'ja-JP')
}
