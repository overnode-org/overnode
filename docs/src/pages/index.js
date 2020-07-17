import React from 'react';
import classnames from 'classnames';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

import ThumbUpIcon from '@material-ui/icons/ThumbUp';
import ExtensionIcon from '@material-ui/icons/Extension';
import SpeedIcon from '@material-ui/icons/Speed';
import BuildIcon from '@material-ui/icons/Build';
import { PreviewSample } from '../PreviewSample';

const features = [
  {
    title: <>Very easy to use</>,
    imageUrl: <ThumbUpIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        Learn in 15 minutes <Link to={'docs/getting-started'}>Getting Started</Link> and other code samples to learn it in minutes.
      </>
    ),
  },
  {
    title: <>Production graded</>,
    imageUrl: <ExtensionIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        TBD and <Link to={'docs/extensions-overview'}>a lot more...</Link>
      </>
    ),
  },
  {
    title: <>Config samples for 1000x apps</>,
    imageUrl: <SpeedIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        TBD <Link to={'docs/performance-intro'}>Learn more...</Link>.
      </>
    ),
  },
  {
    title: <>Predictable and transparent</>,
    imageUrl: <code style={{ height: 100, fontSize: 70, color: '#606876' }}>f()</code>,
    description: (
      <>
        Static container placement <Link to={'docs/getting-started'}>a lot more...</Link>
      </>
    ),
  },
  {
    title: <>Automated rollover upgrade</>,
    imageUrl: <code style={{ height: 100, fontSize: 70, color: '#606876' }}>TS</code>,
    description: (
      <>
        TBD
      </>
    ),
  },
  {
    title: <>Off the shelf devops infrastructure</>,
    imageUrl: <BuildIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        Metrics, weavescope visibility, logs <Link to={'docs/devtools'}>a lot more...</Link>
      </>
    ),
  },
];

function Feature({imageUrl, title, description}) {
  // const imgUrl = useBaseUrl(imageUrl);
  return (
    <div className={classnames('col col--4', styles.feature)}>
      <div style={{ textAlign: 'left', width: '100%', color: '#606876' }}>{imageUrl}</div>
      <h3>{title}</h3>
      <p>{description}</p>
    </div>
  );
}

function Home() {
  let sample = ""
  sample += "1. # Install overnode for the required hosts:\n"
  sample += "hostX > wget --no-cache -O - https://raw.githubusercontent.com/avkonst/overnode/master/install.sh | sudo sh\n"
  sample += "\n"
  sample += "2. # Add hosts to the cluster:\n"
  sample += "host1 > sudo overnode launch --id 1 --token my-cluster-password host1 host2 host3\n"
  sample += "host2 > sudo overnode launch --id 2 --token my-cluster-password host1 host2 host3\n"
  sample += "host3 > sudo overnode launch --id 3 --token my-cluster-password host1 host2 host3\n"
  sample += "\n"
  sample += "3. # Create new project, optionally adding pre-configured stacks:\n"
  sample += "host1 > sudo overnode init --project my-project \\ \n"
  sample += "host1 >        https://github.com/avkonst/overnode@examples/infrastructure/weavescope \\\n"
  sample += "host1 >        https://github.com/avkonst/overnode@examples/infrastructure/prometheus \\\n"
  sample += "host1 >        https://github.com/avkonst/overnode@examples/infrastructure/loki       \\\n"
  sample += "host1 >        https://github.com/avkonst/overnode@examples/infrastructure/grafana    \n"
  sample += "\n"
  sample += "4. # [Optional] Adjust containers placement:\n"
  sample += "host1 > nano overnode.yml\n"
  sample += "\n"
  sample += "5. # (Re-)deploy containers to the cluster:\n"
  sample += "host1 > sudo overnode up # run once from any host in the cluster"

  
  const context = useDocusaurusContext();
  const {siteConfig = {}} = context;
  return (
    <Layout
      title={`${siteConfig.title}: predictable container orchestration`}
      description="Predictable container deployment and management on top of automated multi-host docker-compose">
      <header className={classnames('hero hero--primary', styles.heroBanner)}>
        <div className="container">
          <h1 className={classnames('hero__title', styles.heroTitle)}>{siteConfig.title}</h1>
          <p className="hero__subtitle">{siteConfig.tagline}</p>
          <div className={styles.buttons}>
            <Link
              className={classnames(
                'button button--outline button--secondary button--lg',
                styles.getStarted,
              )}
              to={useBaseUrl('docs/getting-started')}>
              Get Started
            </Link>
          </div>
        </div>
      </header>
      <main>
        {features && features.length && (
          <section className={styles.features}>
            <div className="container">
              <div className="row">
                {features.map((props, idx) => (
                  <Feature key={idx} {...props} />
                ))}
              </div>
            </div>
          </section>
        )}
        <div className="container">
        <PreviewSample code={sample} language="bash" />
        </div>
      </main>
    </Layout>
  );
}

export default Home;
