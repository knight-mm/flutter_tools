### 对于可以连续点击切换状态的按钮的一种优化处理
- 例如收藏、点赞类的功能按钮
- 思路是默认成功 且即时切换状态 待震颤时间过后判断当前状态是否和原始状态一致 不一致再发起请求
- 效果
  ```HTML
  <video src="assets/example.mp4"></video>
  ```
- 地址[https://github.com/knight-mm/flutter_tools/tree/beta/resources/click_debounce]

