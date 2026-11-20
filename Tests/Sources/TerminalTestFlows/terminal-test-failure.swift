struct TerminalTestFailure:
    Error,
    CustomStringConvertible
{
    var probe: String
    var expectation: String
    var observed: String

    init(
        probe: String,
        expectation: String,
        observed: String
    ) {
        self.probe = probe
        self.expectation = expectation
        self.observed = observed
    }

    var description: String {
        """
        \(probe)
          expected  \(expectation)
          observed  \(observed)
        """
    }
}
