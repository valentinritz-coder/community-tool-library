import Image from "next/image";
import Link from "next/link";

const objects = [
  ["raclette.svg", "landing-object--raclette"],
  ["projector.svg", "landing-object--projector"],
  ["table.svg", "landing-object--table"],
  ["hedge-trimmer.svg", "landing-object--trimmer"],
  ["console.svg", "landing-object--console"],
  ["drill.svg", "landing-object--drill"],
  ["watering-can.svg", "landing-object--watering-can"],
] as const;

const joiningSteps = [
  {
    title: "Recevez une invitation",
    copy: "Votre communauté vous transmet son lien ou son code.",
  },
  {
    title: "Créez votre compte",
    copy: "Créez votre compte pour poursuivre votre demande.",
  },
  {
    title: "Demandez à rejoindre",
    copy: "Votre demande est ensuite examinée par la communauté.",
  },
] as const;

export function LandingPage() {
  return (
    <div className="landing" lang="fr">
      <a className="landing-skip-link" href="#contenu">
        Aller au contenu principal
      </a>
      <header className="landing-header">
        <div className="landing-header__inner">
          <span className="landing-wordmark">Communément</span>
          <Link className="landing-link-secondary" href="/app">
            Se connecter
          </Link>
        </div>
      </header>

      <main id="contenu" className="landing-modules">
        <section
          className="landing-section landing-hero"
          aria-labelledby="landing-title"
        >
          <div className="landing-hero__copy">
            <h1 id="landing-title">
              Des <span>objets</span> en commun.
              <br />
              Des <span>décisions</span> en commun.
            </h1>
            <p className="landing-lead">
              Partagez et empruntez des objets au sein de votre communauté
              locale. Simple, humain et fait pour durer.
            </p>
            <Link
              className="landing-button-primary"
              href="/app#join-title"
              aria-describedby="invitation-cue"
            >
              Rejoindre une communauté
            </Link>
            <p id="invitation-cue" className="landing-invitation-cue">
              <span aria-hidden="true">●</span> Accès sur invitation seulement
            </p>
          </div>
          <div className="landing-hero__visual" aria-hidden="true">
            <Image
              src="/illustrations/landing/hero-exchange.webp"
              alt=""
              width={1556}
              height={1011}
              priority
              sizes="(min-width: 60rem) 50vw, 100vw"
            />
          </div>
        </section>

        <section
          className="landing-section landing-objects"
          aria-labelledby="objects-title"
        >
          <div className="landing-centered-copy">
            <h2 id="objects-title">
              Prêt, <span>près</span>, prêtez !
            </h2>
            <p className="landing-subheading">
              Ce dont vous avez besoin est peut-être déjà tout près.
            </p>
            <p>
              Pour bricoler, recevoir, vous équiper ou simplement pour une
              occasion, découvrez ce que votre communauté met en commun.
            </p>
          </div>
          <div className="landing-object-composition" aria-hidden="true">
            {objects.map(([name, className]) => (
              <Image
                key={name}
                className={className}
                src={`/illustrations/landing/objects/${name}`}
                alt=""
                width={240}
                height={180}
                sizes="(min-width: 60rem) 14vw, 31vw"
              />
            ))}
          </div>
        </section>

        <section
          className="landing-section landing-split landing-trust"
          aria-labelledby="trust-title"
        >
          <div className="landing-split__copy">
            <h2 id="trust-title">Partager en confiance</h2>
            <p className="landing-lead">
              Une communauté, ce n’est pas n’importe qui.
            </p>
            <p>
              L’accès se fait sur invitation et chaque demande d’adhésion doit
              être acceptée avant de donner accès à la communauté.
            </p>
          </div>
          <div className="landing-split__visual" aria-hidden="true">
            <Image
              src="/illustrations/landing/handshake.webp"
              alt=""
              width={1672}
              height={941}
              sizes="(min-width: 60rem) 48vw, 100vw"
            />
          </div>
        </section>

        <section
          className="landing-section landing-split landing-vote"
          aria-labelledby="vote-title"
        >
          <div className="landing-split__copy">
            <h2 id="vote-title">À voter !</h2>
            <p className="landing-lead">
              Votre communauté peut choisir celles et ceux qui la représentent.
            </p>
            <p>
              Les membres élisent leur conseil, qui prend ensuite en charge les
              décisions et l’administration de la communauté.
            </p>
          </div>
          <div className="landing-split__visual" aria-hidden="true">
            <Image
              src="/illustrations/landing/council-ballot.webp"
              alt=""
              width={1536}
              height={1024}
              sizes="(min-width: 60rem) 52vw, 100vw"
            />
          </div>
        </section>

        <section
          className="landing-section landing-join"
          aria-labelledby="join-title"
        >
          <div className="landing-copy">
            <h2 id="join-title">Comment rejoindre ?</h2>
            <p className="landing-lead">
              Suivez ces trois étapes simples pour rejoindre votre communauté.
            </p>
          </div>
          <ol className="landing-steps">
            {joiningSteps.map((step) => (
              <li key={step.title}>
                <h3>{step.title}</h3>
                <p>{step.copy}</p>
              </li>
            ))}
          </ol>
        </section>

        <section
          className="landing-section landing-project"
          aria-labelledby="project-title"
        >
          <div className="landing-project__copy">
            <h2 id="project-title">
              Et si votre communauté n’existe pas encore ?
            </h2>
            <p>
              Communément est un service pour les collectivités, associations et
              structures locales. Nous vous accompagnons pour lancer votre
              communauté clé en main.
            </p>
            <button
              className="landing-button-primary"
              type="button"
              disabled
              aria-describedby="contact-pending"
            >
              Nous contacter
            </button>
            <p id="contact-pending" className="landing-small">
              Le parcours de contact sera bientôt disponible.
            </p>
          </div>
          <dl className="landing-audiences">
            <div>
              <dt>Pour les mairies</dt>
              <dd>Développer le partage et le lien entre habitants.</dd>
            </div>
            <div>
              <dt>Pour les associations</dt>
              <dd>Proposer un service utile aux membres.</dd>
            </div>
            <div>
              <dt>Pour les structures locales</dt>
              <dd>Construire la communauté avec l’opérateur.</dd>
            </div>
          </dl>
        </section>
      </main>

      <footer className="landing-footer">
        <div className="landing-footer__inner">
          <div>
            <p className="landing-wordmark">Communément</p>
            <p>
              Des objets en commun.
              <br />
              Des décisions en commun.
            </p>
          </div>
          <div className="landing-footer__labels">
            <span>Contact</span>
            <span>Accessibilité</span>
            <span>Confidentialité</span>
            <span>Mentions légales</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
