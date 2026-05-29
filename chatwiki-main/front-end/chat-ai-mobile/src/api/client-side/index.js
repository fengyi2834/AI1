import request from '@/utils/http/axios'

export const getClientSideRobotPortal = (params = {}) => {
  return request.get({
    url: '/manage/clientSide/getRobotList',
    params
  })
}
