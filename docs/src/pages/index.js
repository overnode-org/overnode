import React from 'react';
import classnames from 'classnames';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

import ThumbUpAltTwoToneIcon from '@material-ui/icons/ThumbUpAltTwoTone';
import DoneAllTwoToneIcon from '@material-ui/icons/DoneAllTwoTone';
import EqualizerTwoToneIcon from '@material-ui/icons/EqualizerTwoTone';
import AutorenewTwoToneIcon from '@material-ui/icons/AutorenewTwoTone';
import FileCopyTwoToneIcon from '@material-ui/icons/FileCopyTwoTone';
import CollectionsBookmarkTwoToneIcon from '@material-ui/icons/CollectionsBookmarkTwoTone';

import { PreviewSample } from '../PreviewSample';

const features = [
  {
    title: <>Very easy to use</>,
    imageUrl: <ThumbUpAltTwoToneIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        Overnode is as easy as <Link to="https://docs.docker.com/compose/">Docker Compose</Link>.<br />
        You need only 15 minutes to learn <i>multi-host</i> part of it.
        Secure network is run by <Link to="https://www.weave.works/oss/net/">Weavenet</Link>,
        which is famous for its simplicity and great ops
        tools. <Link to="docs/getting-started">Learn more...</Link>
      </>
    ),
  },
  {
    title: <>Production graded</>,
    imageUrl:  <DoneAllTwoToneIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        Once your containers are up and running,<br/>
        <Link to="https://docs.docker.com/">Docker</Link> and <Link to="https://www.weave.works/oss/net/">Weavenet</Link> are the only
        runtime acting components of the tool.<br/> Both power many known small and large scale
        production deployments.
      </>
    ),
  },
  {
    title: <>Config samples for 1000x apps</>,
    imageUrl: <FileCopyTwoToneIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        We bet you can find suitable Docker Compose configuration for any more or less known application.
        All of them will require only minor or no changes to work with specifics of your overnode cluster.
      </>
    ),
  },
  {
    title: <>Flexible and predictable</>,
    imageUrl: <CollectionsBookmarkTwoToneIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        You have got <u>full control of all of the parameters of containers</u>, including names, sub-networks,
        ip addresses, DNS names, volumes, environment variables, etc. <u>and also placement across hosts</u>.
        Overnode changes it only when an operator applies new or updated configurations.
      </>
    ),
  },
  {
    title: <>Automated rollover upgrade</>,
    imageUrl: <AutorenewTwoToneIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        Upgrade your stacks with a piece of mind.
        Overnode can apply configurations and recreate services layer-by-layer and / or node-by-node,
        ensuring healthy status of the upgraded components at each step.
      </>
    ),
  },
  {
    title: <>Off the shelf devops infrastructure</>,
    imageUrl: <EqualizerTwoToneIcon style={{ width: 100, height: 100 }} />,
    description: (
      <>
        Save time on setting up your devops tools.
        Overnode provides optional pre-configured off the shelf
        stacks: <u>monitoring and alerting</u> by Prometheus, <u>central logging</u> by Loki, <u>metrics and logs browsing</u> by Grafana, <u>awesome interactive display</u> by Weave Scope.
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
  sample += "hostX > wget --no-cache -O - https://overnode.org/install | sudo sh\n"
  sample += "\n"
  sample += "2. # Form a cluster:\n"
  sample += "host1 > sudo overnode launch --id 1 --token my-cluster-password host1 host2 host3\n"
  sample += "host2 > sudo overnode launch --id 2 --token my-cluster-password host1 host2 host3\n"
  sample += "host3 > sudo overnode launch --id 3 --token my-cluster-password host1 host2 host3\n"
  sample += "\n"
  sample += "3. # Create new project, optionally adding pre-configured stacks (yours or 3rd party):\n"
  sample += "host1 > sudo overnode init --project my-project \\ \n"
  sample += "host1 >        https://github.com/overnode-org/overnode@examples/infrastructure/weavescope \\\n"
  sample += "host1 >        https://github.com/overnode-org/overnode@examples/infrastructure/prometheus \\\n"
  sample += "host1 >        https://github.com/overnode-org/overnode@examples/infrastructure/loki       \\\n"
  sample += "host1 >        https://github.com/overnode-org/overnode@examples/infrastructure/grafana    \n"
  sample += "\n"
  sample += "4. # Adjust containers placement, if necessary:\n"
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
