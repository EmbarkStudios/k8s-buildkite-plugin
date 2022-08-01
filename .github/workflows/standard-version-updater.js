module.exports.readVersion = function (contents) {
    const regex = new RegExp("'muhlba91\/buildkite-agent-k8s:(.*)'", "g");
    const match = regex.exec(contents);
    return match[1];
}

module.exports.writeVersion = async function (contents, version) {
    return contents.replace(/'muhlba91\/buildkite-agent-k8s:.*'/g, `'muhlba91/buildkite-agent-k8s:${version}'`);
}
