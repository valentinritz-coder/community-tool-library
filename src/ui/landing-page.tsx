export function LandingPage() {
  return (
    <div className="page">
      <a className="skip-link" href="#main">
        Skip to main content
      </a>

      <header className="header">
        <span className="brand">
          <span className="brand-mark" aria-hidden="true">
            CT
          </span>
          Community Tool Library
        </span>
      </header>

      <main className="hero" id="main">
        <div className="hero-content">
          <p className="eyebrow">Share locally. Use more. Own less.</p>
          <h1>Useful tools, shared by neighbours.</h1>
          <p className="intro">
            A simple way for trusted local communities to share small, low-risk
            equipment. The community pilot is being prepared now.
          </p>
          <p className="status">
            <span className="status-dot" aria-hidden="true" />
            Pilot application in development
          </p>
        </div>
      </main>

      <footer className="footer">
        Built for practical sharing in local communities.
      </footer>
    </div>
  );
}
