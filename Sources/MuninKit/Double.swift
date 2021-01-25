infix operator ==~: AssignmentPrecedence
public func ==~ (lhs: Double, rhs: Double) -> Bool {
  return lhs == rhs
    || lhs + lhs.ulp == rhs
    || lhs - lhs.ulp == rhs
}

public func ==~ (lhsWrapped: Double?, rhsWrapped: Double?) -> Bool {
  if let lhs = lhsWrapped, let rhs = rhsWrapped {
    return lhs == rhs
      || lhs + lhs.ulp == rhs
      || lhs - lhs.ulp == rhs

  }
  return lhsWrapped == rhsWrapped
}
