import uglify from '@lopatnov/rollup-plugin-uglify';
import typescript from '@rollup/plugin-typescript';
import elm from 'rollup-plugin-elm';
import resolve from '@rollup/plugin-node-resolve';

export default (commandLineArgs) => ({
    input: 'src/typescript/main.ts',
    output: {
        file: 'assets/js/code.js',
        format: 'iife',
        sourcemap: !commandLineArgs.deploy
    },
    watch: commandLineArgs.deploy && {
        buildDelay: 100,
        include: 'src/**',
    },
    plugins: [
        elm({
            exclude: 'elm_stuff/**',
            optimize: commandLineArgs.deploy,
            debug: !commandLineArgs.deploy,
        }),
        typescript(),
        resolve(),
        commandLineArgs.deploy && uglify(
            //     { // TODO: see if I need these flags at all
            //     compress: {
            //         pure_funcs: ["F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9"]
            //     },
            //     pure_getters: true,
            //     keep_fargs: false,
            //     unsafe_comps: true,
            //     unsafe: true
            // }
        )
    ],
});