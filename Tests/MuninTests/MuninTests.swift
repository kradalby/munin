import Testing

@Suite
struct MuninTests {
  @Test func smoke() {
    #expect("test" == "test")
  }
}
