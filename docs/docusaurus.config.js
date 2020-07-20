module.exports = {
  title: 'Overnode',
  tagline: 'Predictable container deployment and management on top of automated multi-host docker-compose',
  url: 'https://overnode.org',
  baseUrl: '/',
  favicon: 'img/favicon-32.png',
  projectName: 'overnode-org/overnode',
  themeConfig: {
    disableDarkMode: true,
    navbar: {
      title: 'OVERNODE',
      logo: {
        alt: 'overnode-logo',
        src: 'img/favicon-196.png',
      },
      links: [
        {to: 'docs/getting-started', label: 'Docs', position: 'left'},
        {to: 'blog', label: 'Blog', position: 'left'},
        {
          href: 'https://github.com/overnode-org/overnode',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Getting started',
              to: 'https://overnode.org/docs/getting-started',
            },
            {
              label: 'CLI reference',
              to: 'https://overnode.org/docs/cli-reference',
            },
          ],
        },
        {
          title: 'Infrastructure',
          items: [
            {
              label: 'Network visibility',
              href: 'https://overnode.org/docs',
            },
            {
              label: 'Monitoring and alerting',
              href: 'https://overnode.org/docs',
            },
            {
              label: 'Central logging',
              href: 'https://overnode.org/docs',
            },
          ],
        },
        {
          title: 'Social',
          items: [
            {
              label: 'Blog',
              href: 'https://overnode.org/blog',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/overnode-org/overnode',
            },
            {
              label: 'Discussions',
              href: 'https://github.com/overnode-org/overnode/issues?q=is%3Aissue+is%3Aopen+label%3Aquestion',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Overnode.`,
    },
  },
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl:
            'https://github.com/overnode-org/overnode/edit/master/docs',
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ]
};
