import { genMessage } from '../helper'

const modulesFiles = import.meta.glob<Recordable>('./ko-KR/**/*.json', { eager: true })

export default {
  ...genMessage(modulesFiles, 'ko-KR')
}
