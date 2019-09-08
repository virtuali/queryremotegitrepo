#!/usr/bin/php
<?php
/**
 *
 */
namespace App;

use Exception;

// config
const MIN_PHP_MAJOR_VERSION = 5;
const MIN_PHP_MINOR_VERSION = 1;
const MIN_PHP_RELEASE_VERSION = '00';
const MIN_GIT_VERSION = 2;
const APP_TITLE = 'Query remote git repo and display last commit sha. Call format:' . PHP_EOL .
    'usage: app -r ... -b ... [--service ...] [--help]' . PHP_EOL;
const APP_HELP_PARAM_NAME = 'help';
const APP_PARAMS = [ // : - required, :: - optional, for details check getopt() options formatting
    'required' => [
        'r:' => "\t\trequired repo name",
        'b:' => "\t\trequired branch name"
    ],
    'optional' => [
        'service::' => "\tservice name, for now only \"github\" is supported",
        APP_HELP_PARAM_NAME => "\t\tdisplay this help"
    ]
];
const APP_DESC_FOOT = PHP_EOL. 'usage example: ' . PHP_EOL .
    './app -r laravel-shift/laravel-5.3 -b master' . PHP_EOL .
    './app -r atlassian/bitbucketjs -b master --service=bitbucked' . PHP_EOL .
    './app --help';

// app start
Helpers::validate_php_version();
Helpers::validate_git_exists();
try {
    $repo = new Repo(Helpers::get_input_data());
} catch (Exception $e) {
    Helpers::echo_err($e->getMessage());
}

if ($sha = $repo->getLastLommitSha()) {
    Helpers::echo_info($repo->getLastLommitSha());
} else {
    Helpers::echo_err('Unknown or empty branch');
}
exit();
// app end

/**
 * Repository query class - probably too mutch for this use case but
 * lets add some OOP and extend or substitute by more advaned library
 * if needed
 */
class Repo
{
    const DEFAULT_SERVICE = 'github';
    const SERVICES = [self::DEFAULT_SERVICE => 'https://github.com/'];
    protected $currentRepo = '';
    protected $currentBranch = '';
    protected $serviceUrl = null;

    public function __construct($args)
    {
        if (!isset($args['repo']) || !isset($args['branch'])) throw new Exception("Missing repository or branch name");

        if (!$args['service']) $args['service'] = self::DEFAULT_SERVICE;
        $this->serviceUrl = self::SERVICES[$args['service']] ?: Helpers::_die('Unsupported service ' . $args['service']);
        $this->setBranch($args['branch']);
        $this->setRepo($args['repo']);
    }

    /**
     * Set repo name if valid
     * @param $name
     * @return void
     */
    protected function setRepo($name)
    {
        if ($name && $this->validateRepositoryName($name)) {
            $this->currentRepo = $name;
            return;
        }
        Helpers::_die('Unvalid repository name or url ' . $this->serviceUrl . ' is unavailable');
    }

    /**
     * Set branch name if valid
     * @param $name
     * @return void
     */
    protected function setBranch($name)
    {
        if ($name && $this->validateBranchName($name)) {
            $this->currentBranch = $name;
            return;
        }
        Helpers::_die("Can't set current branch name." . PHP_EOL);
    }

    /**
     * get last commit sha for current branch
     * @return bool|mixed
     */
    public function getLastLommitSha()
    {
        $cmd = "git ls-remote --head " . $this->serviceUrl . $this->currentRepo;
        $output = shell_exec($cmd);
        $separator = "\r\n";
        $line = strtok($output, $separator);
        while ($line != false) { // iterate through returned branches
            $branch = explode("\t", $line);
            if ($branch[1] == 'refs/heads/' . $this->currentBranch) {
                return $branch[0];
            }

            $line = strtok($separator);
        }
        return null;
    }

    /**
     * Validate branch name
     * @param $name
     * @return bool
     */
    protected function validateBranchName($name)
    {
        if (substr($name, -1, 1) !== '\\') {
            $filteredName = trim(shell_exec('git check-ref-format --branch ' . $name));
            if ($name === $filteredName) {
                return true;
            }
        }
        Helpers::_die ("Unvalid branch name.");
    }

    protected function validateRepositoryName($name)
    {
        if ($this->validateIsRemoteUrlLive($this->serviceUrl . $name)) {
            return true;
        }
        Helpers::_die('Remote repository url is unavailable.');
    }

    /**
     * validate if remote repository url is live
     *
     * @param string $url
     * @param array $opts
     * @return bool|mixed
     */
    protected  function validateIsRemoteUrlLive($url, array $opts = [])
    {
        // Store previous default context
        $prev = stream_context_get_options(stream_context_get_default());

        // Set new one with head and a small timeout
        stream_context_set_default(['http' => $opts +
            [
                'method' => 'HEAD',
                'timeout' => 2,
            ]]);

        // Do the head request
        $headers = @get_headers($url, true);
        if (!$headers)
            return false;

        // Restore previous default context and return
        stream_context_set_default($prev);

        preg_match('/\s(\d+)\s/', $headers[0], $matches);

        if (trim($matches[0]) == '200') return true;

        return false;
    }

    protected function validateIsNotEmptyHEADBranch()
    {

    }
}

class Helpers {
    /**
     * Parse app input data and
     * @return array
     */
    public static function get_input_data()
    {
        $options = implode(array_keys(APP_PARAMS['required']));
        $longopts = explode('@', implode('@', array_keys(APP_PARAMS['optional'])));//array_keys($params['optional']);
        $arguments = getopt($options, $longopts);

        // check if help was invoked or all required parameters provided
        if (array_key_exists(APP_HELP_PARAM_NAME, $arguments) || !$arguments['r'] || !$arguments['b']) {
            if (!$arguments['r'] xor !$arguments['b'] ) {
                Helpers::echo_err('*** There is some problem with paramteres. ***' . PHP_EOL);
            }
            Helpers::display_help();
            die();
        }

        return ['repo' => $arguments['r'], 'branch' => $arguments['b'], 'service' => $arguments['service']];
    }

    public static function display_help()
    {
        Helpers::echo_info(APP_TITLE . PHP_EOL . 'Required parameters:');
        foreach (APP_PARAMS['required'] as $param => $param_desc) {
            Helpers::echo_info ('-' . Helpers::sc($param) . $param_desc);
        }

        Helpers::echo_info ('Optional parameters:');
        foreach (APP_PARAMS['optional'] as $param => $param_desc) {
            Helpers::echo_info ('--' . Helpers::sc($param) . $param_desc);
        }

        Helpers::echo_info(APP_DESC_FOOT);
    }

    /**
     * Validate git requirements
     * @return void
     */
    public static function validate_git_exists()
    {
        if ($str = shell_exec('git --version')) {
            $git_data = explode(' ', $str);
            if ($git_data[0] != 'git' || !is_array(($gitVersion = explode('.', $git_data[2]))) || $gitVersion[0] != MIN_GIT_VERSION) {
                Helpers::_die('This app requires git ' . MIN_GIT_VERSION . '.*');
            }
        }
    }

    /**
     * Validate php environment
     * @return void
     */
    public static function validate_php_version()
    {
        $version = explode('.', phpversion());
        if (!defined('PHP_VERSION_ID')) {
            define('PHP_VERSION_ID', ($version[0] * 10000 + $version[1] * 100 + $version[2]));
        }

        if (PHP_VERSION_ID < MIN_PHP_MAJOR_VERSION * 10000 + MIN_PHP_MINOR_VERSION * 100 + MIN_PHP_RELEASE_VERSION) {
            if (!defined('PHP_MAJOR_VERSION')) {
                define('PHP_MAJOR_VERSION', $version[0]);
            }
            if (!defined('PHP_MINOR_VERSION')) {
                define('PHP_MINOR_VERSION', $version[1]);
            }
            if (!defined('PHP_VERSION_ID')) {
                define('PHP_VERSION_ID', $version[1]);
            }
            Helpers::echo_info('Your PHP_MAJOR_VERSION:' . PHP_MAJOR_VERSION);
            Helpers::echo_info('Your PHP_MINOR_VERSION:' . PHP_MINOR_VERSION);
            Helpers::echo_info('Your PHP_VERSION_ID:' . PHP_VERSION_ID);
            Helpers::_die('This script requires at least PHP v.' . MIN_PHP_MAJOR_VERSION . '.' . MIN_PHP_RELEASE_VERSION . ' or higher');
        }
    }

    /**
     * Remove colons from string
     * @return string
     */
    public static function sc($str)
    {
        return str_replace(':', '', $str);
    }

    /**
     * @param $str
     */
    public static function echo_err($str)
    {
        echo "\033[31m" . $str . PHP_EOL;
    }

    /**
     * @param $str
     */
    public static function echo_info($str)
    {
        echo "\033[39m" . $str . PHP_EOL;
    }

    /**
     * @param $msg
     */
    public static function _die($msg)
    {
        die("\033[31m" . $msg . PHP_EOL);
    }
}
