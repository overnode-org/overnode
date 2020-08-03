module.exports = {
    someSidebar: {
        'Getting Started': [
            'getting-started',
            'installation',
            'managing-cluster',
            {
                'Managing Containers': [
                    'managing-containers-workflow',
                    'service-discovery'
                ]
            },
        ],
        'Pre-configured Infrastructure': [
            'monitoring-and-alerting',
            'central-logging',
            'network-browsing'
        ],
        'Configuration Reference': [
            'overnode-yml-file-description',
            'docker-compose-yml-file-description',
            'dotenv-file-description',
            'overnodeignore-file-description'
        ],
        'CLI Reference': [
            'cli-reference',
            {
                '- Nodes Management': [
                    'cli-reference/install',
                    'cli-reference/upgrade',
                    'cli-reference/launch',
                    'cli-reference/prime',
                    'cli-reference/resume',
                    'cli-reference/connect',
                    'cli-reference/forget',                            
                ]
            },
            {
                '- Containers Management': [
                    'cli-reference/up',
                    'cli-reference/down',
                    'cli-reference/start',
                    'cli-reference/stop',
                    'cli-reference/restart',
                    'cli-reference/pause',
                    'cli-reference/unpause',
                    'cli-reference/kill',
                    'cli-reference/rm',
                    'cli-reference/pull',
                    'cli-reference/push',                            
                ]
            },
            {
                '- Configuration Related': [
                    'cli-reference/init',
                    'cli-reference/login',
                    'cli-reference/logout',
                    'cli-reference/expose',
                    'cli-reference/hide',
                    'cli-reference/dns-lookup',
                    'cli-reference/dns-add',
                    'cli-reference/dns-remove',
                ]
            },
            {
                '- Status and Inspection': [
                    'cli-reference/ps',
                    'cli-reference/logs',
                    'cli-reference/top',
                    'cli-reference/events',
                    'cli-reference/config',
                    'cli-reference/status',
                    'cli-reference/inspect',
                    'cli-reference/help',
                    'cli-reference/version',
                ]
            }
        ],
    },
};
