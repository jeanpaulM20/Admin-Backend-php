<?php
/**
 * This file contains classes implementing security manager feature.
 *
 * @author Qiang Xue <qiang.xue@gmail.com>
 * @link http://www.yiiframework.com/
 * @copyright Copyright &copy; 2008-2011 Yii Software LLC
 * @license http://www.yiiframework.com/license/
 */

/**
 * CSecurityManager provides private keys, hashing and encryption functions.
 *
 * CSecurityManager is used by Yii components and applications for security-related purpose.
 * For example, it is used in cookie validation feature to prevent cookie data
 * from being tampered.
 *
 * CSecurityManager is mainly used to protect data from being tampered and viewed.
 * It can generate HMAC and encrypt the data. The private key used to generate HMAC
 * is set by {@link setValidationKey ValidationKey}. The key used to encrypt data is
 * specified by {@link setEncryptionKey EncryptionKey}. If the above keys are not
 * explicitly set, random keys will be generated and used.
 *
 * To protected data with HMAC, call {@link hashData()}; and to check if the data
 * is tampered, call {@link validateData()}, which will return the real data if
 * it is not tampered. The algorithm used to generated HMAC is specified by
 * {@link validation}.
 *
 * To encrypt and decrypt data, call {@link encrypt()} and {@link decrypt()}
 * respectively. These methods rely on the OpenSSL extension and the cipher
 * specified via {@link cryptAlgorithm}.
 *
 * CSecurityManager is a core application component that can be accessed via
 * {@link CApplication::getSecurityManager()}.
 *
 * @property string $validationKey The private key used to generate HMAC.
 * If the key is not explicitly set, a random one is generated and returned.
 * @property string $encryptionKey The private key used to encrypt/decrypt data.
 * If the key is not explicitly set, a random one is generated and returned.
 * @property string $validation
 *
 * @author Qiang Xue <qiang.xue@gmail.com>
 * @version $Id: CSecurityManager.php 3555 2012-02-09 10:29:44Z mdomba $
 * @package system.base
 * @since 1.0
 */
class CSecurityManager extends CApplicationComponent
{
	const STATE_VALIDATION_KEY='Yii.CSecurityManager.validationkey';
	const STATE_ENCRYPTION_KEY='Yii.CSecurityManager.encryptionkey';

	/**
	 * @var string the name of the hashing algorithm to be used by {@link computeHMAC}.
	 * See {@link http://php.net/manual/en/function.hash-algos.php hash-algos} for the list of possible
	 * hash algorithms. Note that if you are using PHP 5.1.1 or below, you can only use 'sha1' or 'md5'.
	 *
	 * Defaults to 'sha1', meaning using SHA1 hash algorithm.
	 * @since 1.1.3
	 */
	public $hashAlgorithm='sha1';
        /**
         * @var string the name of the cipher algorithm to be used by {@link encrypt} and {@link decrypt}.
         * This should be one of the cipher methods supported by OpenSSL and returned by
         * {@link http://php.net/manual/en/function.openssl-get-cipher-methods.php openssl_get_cipher_methods()}.
         *
         * Defaults to 'AES-256-CBC'.
         * @since 1.1.3
         */
        public $cryptAlgorithm='AES-256-CBC';

	private $_validationKey;
        private $_encryptionKey;
        private $_mbstring;

        public function init()
        {
                parent::init();
                $this->_mbstring=extension_loaded('mbstring');
                if(!extension_loaded('openssl'))
                        throw new CException(Yii::t('yii','CSecurityManager requires PHP OpenSSL extension to be loaded in order to use data encryption feature.'));
        }

	/**
	 * @return string a randomly generated private key
	 */
	protected function generateRandomKey()
	{
		return sprintf('%08x%08x%08x%08x',mt_rand(),mt_rand(),mt_rand(),mt_rand());
	}

	/**
	 * @return string the private key used to generate HMAC.
	 * If the key is not explicitly set, a random one is generated and returned.
	 */
	public function getValidationKey()
	{
		if($this->_validationKey!==null)
			return $this->_validationKey;
		else
		{
			if(($key=Yii::app()->getGlobalState(self::STATE_VALIDATION_KEY))!==null)
				$this->setValidationKey($key);
			else
			{
				$key=$this->generateRandomKey();
				$this->setValidationKey($key);
				Yii::app()->setGlobalState(self::STATE_VALIDATION_KEY,$key);
			}
			return $this->_validationKey;
		}
	}

	/**
	 * @param string $value the key used to generate HMAC
	 * @throws CException if the key is empty
	 */
	public function setValidationKey($value)
	{
		if(!empty($value))
			$this->_validationKey=$value;
		else
			throw new CException(Yii::t('yii','CSecurityManager.validationKey cannot be empty.'));
	}

	/**
	 * @return string the private key used to encrypt/decrypt data.
	 * If the key is not explicitly set, a random one is generated and returned.
	 */
	public function getEncryptionKey()
	{
		if($this->_encryptionKey!==null)
			return $this->_encryptionKey;
		else
		{
			if(($key=Yii::app()->getGlobalState(self::STATE_ENCRYPTION_KEY))!==null)
				$this->setEncryptionKey($key);
			else
			{
				$key=$this->generateRandomKey();
				$this->setEncryptionKey($key);
				Yii::app()->setGlobalState(self::STATE_ENCRYPTION_KEY,$key);
			}
			return $this->_encryptionKey;
		}
	}

	/**
	 * @param string $value the key used to encrypt/decrypt data.
	 * @throws CException if the key is empty
	 */
	public function setEncryptionKey($value)
	{
		if(!empty($value))
			$this->_encryptionKey=$value;
		else
			throw new CException(Yii::t('yii','CSecurityManager.encryptionKey cannot be empty.'));
	}

	/**
	 * This method has been deprecated since version 1.1.3.
	 * Please use {@link hashAlgorithm} instead.
	 * @return string
	 */
	public function getValidation()
	{
		return $this->hashAlgorithm;
	}

	/**
	 * This method has been deprecated since version 1.1.3.
	 * Please use {@link hashAlgorithm} instead.
	 * @param string $value -
	 */
	public function setValidation($value)
	{
		$this->hashAlgorithm=$value;
	}

        /**
         * Encrypts data.
         * @param string $data data to be encrypted.
         * @param string $key the decryption key. This defaults to null, meaning using {@link getEncryptionKey EncryptionKey}.
         * @return string the encrypted data
         * @throws CException if PHP OpenSSL extension is not loaded or cipher method is unsupported
         */
        public function encrypt($data,$key=null)
        {
                $cipher=$this->getCipher();
                $key=$this->prepareKey($key===null ? md5($this->getEncryptionKey()) : $key,$cipher);
                $ivLength=openssl_cipher_iv_length($cipher);
                $iv=openssl_random_pseudo_bytes($ivLength);
                $encrypted=openssl_encrypt($data,$cipher,$key,OPENSSL_RAW_DATA,$iv);
                if($encrypted===false)
                        throw new CException(Yii::t('yii','Failed to initialize the OpenSSL cipher method.'));
                return $iv.$encrypted;
        }

        /**
         * Decrypts data
         * @param string $data data to be decrypted.
         * @param string $key the decryption key. This defaults to null, meaning using {@link getEncryptionKey EncryptionKey}.
         * @return string the decrypted data
         * @throws CException if PHP OpenSSL extension is not loaded or cipher method is unsupported
         */
        public function decrypt($data,$key=null)
        {
                $cipher=$this->getCipher();
                $key=$this->prepareKey($key===null ? md5($this->getEncryptionKey()) : $key,$cipher);
                $ivLength=openssl_cipher_iv_length($cipher);
                $iv=$this->substr($data,0,$ivLength);
                $decrypted=openssl_decrypt($this->substr($data,$ivLength,$this->strlen($data)),$cipher,$key,OPENSSL_RAW_DATA,$iv);
                if($decrypted===false)
                        throw new CException(Yii::t('yii','Failed to initialize the OpenSSL cipher method.'));
                return rtrim($decrypted,"\0");
        }

        /**
         * Returns the cipher method to be used for encryption/decryption.
         * @return string the cipher method name
         * @throws CException if OpenSSL extension is not loaded or method unsupported
         */
        protected function getCipher()
        {
                if(!extension_loaded('openssl'))
                        throw new CException(Yii::t('yii','CSecurityManager requires PHP OpenSSL extension to be loaded in order to use data encryption feature.'));

                $cipher=is_array($this->cryptAlgorithm) ? $this->cryptAlgorithm[0] : $this->cryptAlgorithm;
                if(!in_array($cipher, openssl_get_cipher_methods()))
                        throw new CException(Yii::t('yii','Failed to initialize the OpenSSL cipher method.'));

                return $cipher;
        }

        /**
         * Prepares the key according to the chosen cipher method.
         * @param string $key base key value
         * @param string $cipher cipher method name
         * @return string key padded or truncated to required length
         */
        protected function prepareKey($key,$cipher)
        {
                $length=0;
                if(preg_match('/-(\d+)-/',$cipher,$m))
                        $length=intval($m[1])/8;
                elseif(stripos($cipher,'DES-EDE3')!==false)
                        $length=24;
                elseif(stripos($cipher,'DES')!==false)
                        $length=8;
                if($length>0)
                        return $this->substr($key,0,$length);
                else
                        return $key;
        }

	/**
	 * Prefixes data with an HMAC.
	 * @param string $data data to be hashed.
	 * @param string $key the private key to be used for generating HMAC. Defaults to null, meaning using {@link validationKey}.
	 * @return string data prefixed with HMAC
	 */
	public function hashData($data,$key=null)
	{
		return $this->computeHMAC($data,$key).$data;
	}

	/**
	 * Validates if data is tampered.
	 * @param string $data data to be validated. The data must be previously
	 * generated using {@link hashData()}.
	 * @param string $key the private key to be used for generating HMAC. Defaults to null, meaning using {@link validationKey}.
	 * @return string the real data with HMAC stripped off. False if the data
	 * is tampered.
	 */
	public function validateData($data,$key=null)
	{
		$len=$this->strlen($this->computeHMAC('test'));
		if($this->strlen($data)>=$len)
		{
			$hmac=$this->substr($data,0,$len);
			$data2=$this->substr($data,$len,$this->strlen($data));
			return $hmac===$this->computeHMAC($data2,$key)?$data2:false;
		}
		else
			return false;
	}

	/**
	 * Computes the HMAC for the data with {@link getValidationKey ValidationKey}.
	 * @param string $data data to be generated HMAC
	 * @param string $key the private key to be used for generating HMAC. Defaults to null, meaning using {@link validationKey}.
	 * @return string the HMAC for the data
	 */
	protected function computeHMAC($data,$key=null)
	{
		if($key===null)
			$key=$this->getValidationKey();

		if(function_exists('hash_hmac'))
			return hash_hmac($this->hashAlgorithm, $data, $key);

		if(!strcasecmp($this->hashAlgorithm,'sha1'))
		{
			$pack='H40';
			$func='sha1';
		}
		else
		{
			$pack='H32';
			$func='md5';
		}
		if($this->strlen($key) > 64)
			$key=pack($pack, $func($key));
		if($this->strlen($key) < 64)
			$key=str_pad($key, 64, chr(0));
		$key=$this->substr($key,0,64);
		return $func((str_repeat(chr(0x5C), 64) ^ $key) . pack($pack, $func((str_repeat(chr(0x36), 64) ^ $key) . $data)));
	}

	/**
	 * Returns the length of the given string.
	 * If available uses the multibyte string function mb_strlen.
	 * @param string $string the string being measured for length
	 * @return int the length of the string
	 */
	private function strlen($string)
	{
		return $this->_mbstring ? mb_strlen($string,'8bit') : strlen($string);
	}

	/**
	 * Returns the portion of string specified by the start and length parameters.
	 * If available uses the multibyte string function mb_substr
	 * @param string $string the input string. Must be one character or longer.
	 * @param int $start the starting position
	 * @param int $length the desired portion length
	 * @return string the extracted part of string, or FALSE on failure or an empty string.
	 */
	private function substr($string,$start,$length)
	{
		return $this->_mbstring ? mb_substr($string,$start,$length,'8bit') : substr($string,$start,$length);
	}
}
