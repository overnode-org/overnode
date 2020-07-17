import React from 'react'

import Highlight, { PrismTheme, defaultProps, Language } from 'prism-react-renderer';
// import theme from 'prism-react-renderer/themes/palenight';
import theme from 'prism-react-renderer/themes/oceanicNext';

export const PreviewSample = (props: { code: string, language?: Language }) => {
    return <>
        <Highlight {...defaultProps} code={props.code} language={props.language || 'bash' } theme={theme as PrismTheme}>
            {({ className, style, tokens, getLineProps, getTokenProps }) => (
            <pre className={className} style={style}>
                {tokens.map((line, i) => (
                <div key={i} {...getLineProps({ line, key: i })}>
                    {line.map((token, key) => (
                        <span key={key} {...getTokenProps({ token, key })} />
                    ))}
                </div>
                ))}
            </pre>
            )}
        </Highlight>
    </>
};
