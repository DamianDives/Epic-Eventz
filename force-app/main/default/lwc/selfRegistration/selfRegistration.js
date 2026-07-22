import { LightningElement, track } from 'lwc';
import registerUser from '@salesforce/apex/SelfRegistrationController.registerUser';
import loginUser from '@salesforce/apex/SelfRegistrationController.loginUser';

export default class SelfRegistration extends LightningElement {
    @track mode = 'login'; // 'login' or 'signup'
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track password = '';
    @track confirmPassword = '';
    @track isLoading = false;
    @track showSuccess = false;
    @track showError = false;
    @track successMessage = '';
    @track errorMessage = '';

    get isLoginMode() { return this.mode === 'login'; }
    get isSignupMode() { return this.mode === 'signup'; }
    get headerSubtext() {
        return this.mode === 'login'
            ? 'Sign in to register for events'
            : 'Create your account';
    }

    handleFirstNameChange(e) { this.firstName = e.target.value; }
    handleLastNameChange(e) { this.lastName = e.target.value; }
    handleEmailChange(e) { this.email = e.target.value; }
    handlePasswordChange(e) { this.password = e.target.value; }
    handleConfirmPasswordChange(e) { this.confirmPassword = e.target.value; }

    switchToSignup() {
        this.mode = 'signup';
        this.clearMessages();
    }
    switchToLogin() {
        this.mode = 'login';
        this.clearMessages();
    }
    clearMessages() {
        this.showSuccess = false;
        this.showError = false;
        this.successMessage = '';
        this.errorMessage = '';
    }

    async handleSignup() {
        this.clearMessages();
        if (!this.firstName || !this.lastName || !this.email || !this.password) {
            this.showError = true;
            this.errorMessage = 'All fields are required.';
            return;
        }
        if (this.password.length < 8) {
            this.showError = true;
            this.errorMessage = 'Password must be at least 8 characters.';
            return;
        }
        if (this.password !== this.confirmPassword) {
            this.showError = true;
            this.errorMessage = 'Passwords do not match.';
            return;
        }

        this.isLoading = true;
        try {
            const result = await registerUser({
                firstName: this.firstName,
                lastName: this.lastName,
                email: this.email,
                password: this.password
            });
            if (result.success) {
                this.showSuccess = true;
                this.successMessage = result.message;
                // Switch to login after 2 seconds
                setTimeout(() => { this.mode = 'login'; this.showSuccess = false; }, 3000);
            } else {
                this.showError = true;
                this.errorMessage = result.message;
            }
        } catch (error) {
            this.showError = true;
            this.errorMessage = error.body ? error.body.message : 'An error occurred.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleLogin() {
        this.clearMessages();
        if (!this.email || !this.password) {
            this.showError = true;
            this.errorMessage = 'Email and password are required.';
            return;
        }

        this.isLoading = true;
        try {
            const redirectUrl = await loginUser({
                username: this.email,
                password: this.password,
                startUrl: '/s/'
            });
            if (redirectUrl) {
                window.location.href = redirectUrl;
            } else {
                this.showError = true;
                this.errorMessage = 'Invalid email or password. Please try again.';
            }
        } catch (error) {
            this.showError = true;
            this.errorMessage = 'Login failed. Please check your credentials.';
        } finally {
            this.isLoading = false;
        }
    }
}
